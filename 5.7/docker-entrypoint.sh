#!/bin/bash
set -eo pipefail
shopt -s nullglob

# logging functions
mysql_log() {
	local type="$1"; shift
	printf "$(date --rfc-3339=seconds) [${type}] [Entrypoint]: $@\n"
}
mysql_note() {
	mysql_log Note "$@"
}
mysql_warn() {
	mysql_log Warn "$@" >&2
}
mysql_error() {
	mysql_log ERROR "$@" >&2
	exit 1
}

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		mysql_error "Both $var and $fileVar are set (but are exclusive)"
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

# usage: docker_process_init_files [file [file [...]]]
#    ie: docker_process_init_files /always-initdb.d/*
# process initializer files, based on file extensions
docker_process_init_files() {
	# mysql here for backwards compatibility "${mysql[@]}"
	mysql=( docker_process_sql )

	echo
	local f
	for f; do
		case "$f" in
			*.sh)     mysql_note "$0: running $f"; . "$f" ;;
			*.sql)    mysql_note "$0: running $f"; docker_process_sql < "$f"; echo ;;
			*.sql.gz) mysql_note "$0: running $f"; gunzip -c "$f" | docker_process_sql; echo ;;
			*)        mysql_warn "$0: ignoring $f" ;;
		esac
		echo
	done
}

mysql_check_config() {
	local toRun=( "$@" --verbose --help ) errors
	if ! errors="$("${toRun[@]}" 2>&1 >/dev/null)"; then
		mysql_error "mysqld failed while attempting to check config\n\tcommand was: ${toRun[*]}\n\t$errors"
	fi
}

# Fetch value from server config
# We use mysqld --verbose --help instead of my_print_defaults because the
# latter only show values present in config files, and not server defaults
mysql_get_config() {
	local conf="$1"; shift
	"$@" --verbose --help --log-bin-index="$(mktemp -u)" 2>/dev/null \
		| awk -v conf="$conf" '$1 == conf && /^[^ \t]/ { sub(/^[^ \t]+[ \t]+/, ""); print; exit }'
	# match "datadir      /some/path with/spaces in/it here" but not "--xyz=abc\n     datadir (xyz)"
}

# Do a temporary startup of the MySQL server, for init purposes
docker_temp_server_start() {
	local result=0
	"$@" --daemonize --skip-networking --socket="${SOCKET}" || result="$?"
	if [ "$result" != "0" ];then
		mysql_error "Unable to start server. Status code $result."
	fi

	# For 5.7+ the server is ready for use as soon as startup command unblocks
	if [ "${MYSQL_MAJOR}" = "5.5" ] || [ "${MYSQL_MAJOR}" = "5.6" ]; then
		mysql_note "Waiting for server startup"
		local i
		for i in {30..0}; do
			if docker_process_sql --database=mysql <<<'SELECT 1' &> /dev/null; then
				break
			fi
			sleep 1
		done
		if [ "$i" = 0 ]; then
			mysql_error "Unable to start server."
		fi
	fi
}

# Stop the server. When using a local socket file mysqladmin will block until
# the shutdown is complete.
docker_temp_server_stop() {
	local result=0
	mysqladmin --defaults-extra-file=<( echo "${PASSFILE}" ) shutdown -uroot --socket="${SOCKET}" || result=$?
	if [ "$result" != "0" ]; then
		mysql_error "Unable to shut down server. Status code $result."
	fi
}

# Verify that the minimally required password settings are set for new databases.
docker_verify_minimum_env() {
	if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" -a -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
		mysql_error "Database is uninitialized and password option is not specified \n\tYou need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD and MYSQL_RANDOM_ROOT_PASSWORD"
	fi
}

# creates folders for the database
# also ensures permission for user mysql of run as root
docker_create_db_directories() {
	local user; user="$(id -u)"

	# TODO other directories that are used by default? like /var/lib/mysql-files
	# see https://github.com/docker-library/mysql/issues/562
	mkdir -p "$DATADIR"

	if [ "$user" = "0" ]; then
		# this will cause less disk access than `chown -R`
		find "$DATADIR" \! -user mysql -exec chown mysql '{}' +
	fi
}

# initializes the database directory
docker_init_database_dir() {
	mysql_note "Initializing database files"
	"$@" --initialize-insecure
	mysql_note "Database files initialized"

	if command -v mysql_ssl_rsa_setup > /dev/null && [ ! -e "$DATADIR/server-key.pem" ]; then
		# https://github.com/mysql/mysql-server/blob/23032807537d8dd8ee4ec1c4d40f0633cd4e12f9/packaging/deb-in/extra/mysql-systemd-start#L81-L84
		mysql_note "Initializing certificates"
		mysql_ssl_rsa_setup --datadir="$DATADIR"
		mysql_note "Certificates initialized"
	fi
}

# Loads various settings that are used elsewhere in the script
docker_setup_env() {
	# Get config
	DATADIR="$(mysql_get_config 'datadir' "$@")"
	SOCKET="$(mysql_get_config 'socket' "$@")"

	# Initialize values that might be stored in a file
	file_env 'MYSQL_ROOT_HOST' '%'
	file_env 'MYSQL_DATABASE'
	file_env 'MYSQL_USER'
	file_env 'MYSQL_PASSWORD'
	file_env 'MYSQL_ROOT_PASSWORD'
}

# Execute sql script, passed via stdin
# usage: docker_process_sql [mysql-cli-args]
#    ie: docker_process_sql --database=mydb <<<'INSERT ...'
#    ie: docker_process_sql --database=mydb <my-file.sql
docker_process_sql() {
	# args sent in can override this db, since they will be later in the command
	if [ -n "$MYSQL_DATABASE" ]; then
		set -- --database="$MYSQL_DATABASE" "$@"
	fi

	mysql --defaults-file=<( echo "${PASSFILE}" ) --protocol=socket -uroot -hlocalhost --socket="${SOCKET}" "$@"
}

# Initializes database with timezone info and root password, plus optional extra db/user
docker_setup_db() {
	# Load timezone info into database
	if [ -z "$MYSQL_INITDB_SKIP_TZINFO" ]; then
		# sed is for https://bugs.mysql.com/bug.php?id=20545
		mysql_tzinfo_to_sql /usr/share/zoneinfo | sed 's/Local time zone must be set--see zic manual page/FCTY/' | docker_process_sql --database=mysql
	fi
	# Generate random root password
	if [ ! -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
		export MYSQL_ROOT_PASSWORD="$(pwgen -1 32)"
		mysql_note "GENERATED ROOT PASSWORD: $MYSQL_ROOT_PASSWORD"
	fi
	# Sets root password and creates root users for non-localhost hosts
	rootCreate=
	# default root to listen for connections from anywhere
	if [ ! -z "$MYSQL_ROOT_HOST" -a "$MYSQL_ROOT_HOST" != 'localhost' ]; then
		# no, we don't care if read finds a terminating character in this heredoc
		# https://unix.stackexchange.com/questions/265149/why-is-set-o-errexit-breaking-this-read-heredoc-expression/265151#265151
		read -r -d '' rootCreate <<-EOSQL || true
			CREATE USER 'root'@'${MYSQL_ROOT_HOST}' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
			GRANT ALL ON *.* TO 'root'@'${MYSQL_ROOT_HOST}' WITH GRANT OPTION ;
		EOSQL
	fi

	docker_process_sql --database=mysql <<-EOSQL
		-- What's done in this file shouldn't be replicated
		--  or products like mysql-fabric won't work
		SET @@SESSION.SQL_LOG_BIN=0;

		ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
		GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION ;
		FLUSH PRIVILEGES ;
		${rootCreate}
		DROP DATABASE IF EXISTS test ;
	EOSQL

	# Write the password to the "file" the client uses
	# the client command will use process substitution to create a file on the fly
	# ie: --defaults-file=<( echo "${PASSFILE}" )
	if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
		read -r -d '' PASSFILE <<-EOF || true
			[client]
			password="${MYSQL_ROOT_PASSWORD}"
		EOF
	fi

	# Creates a custom database and user if specified
	if [ "$MYSQL_DATABASE" ]; then
		mysql_note "Creating database ${MYSQL_DATABASE}"
		docker_process_sql --database=mysql <<<"CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;"
	fi

	if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
		mysql_note "Creating user ${MYSQL_USER}"
		docker_process_sql --database=mysql <<<"CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;"

		if [ "$MYSQL_DATABASE" ]; then
			mysql_note "Giving user ${MYSQL_USER} access to schema ${MYSQL_DATABASE}"
			docker_process_sql --database=mysql <<<"GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' ;"
		fi

		docker_process_sql --database=mysql <<<"FLUSH PRIVILEGES ;"
	fi
}

# Mark root user as expired so the password must be changed before anything
# else can be done (only supported for 5.6+)
mysql_expire_root_user() {
	if [ ! -z "$MYSQL_ONETIME_PASSWORD" ]; then
		if [ "${MYSQL_MAJOR}" = "5.5" ]; then
			mysql_warn "MySQL 5.5 does not support PASSWORD EXPIRE (required for MYSQL_ONETIME_PASSWORD)"
		else
			docker_process_sql --database=mysql <<-EOSQL
				ALTER USER 'root'@'%' PASSWORD EXPIRE;
			EOSQL
		fi
	fi
}

# check arguments for an option that would cause mysqld to stop
# return true if there is one
_want_help() {
	local arg
	for arg; do
		case "$arg" in
			-'?'|--help|--print-defaults|-V|--version)
				return 0
				;;
		esac
	done
	return 1
}

_main() {
	# if command starts with an option, prepend mysqld
	if [ "${1:0:1}" = '-' ]; then
		set -- mysqld "$@"
	fi

	# skip setup if they aren't running mysqld or want an option that stops mysqld
	if [ "$1" = 'mysqld' ] && ! _want_help "$@"; then
		mysql_note "Entrypoint script for MySQL Server ${MYSQL_VERSION} started."

		# Load various environment variables
		docker_setup_env "$@"
		mysql_check_config "$@"

		# If container is started as root user, restart as dedicated mysql user
		if [ "$(id -u)" = "0" ]; then
			docker_create_db_directories
			mysql_note "Switching to dedicated user 'mysql'"
			exec gosu mysql "$BASH_SOURCE" "$@"
		fi

		# just in case the script was not started as root
		docker_create_db_directories

		# If this is true then there's no database, and it needs to be initialized
		if [ ! -d "$DATADIR/mysql" ]; then
			docker_verify_minimum_env
			docker_init_database_dir "$@"

			mysql_note "Starting temporary server"
			docker_temp_server_start "$@"
			mysql_note "Temporary server started."

			docker_setup_db
			docker_process_init_files /docker-entrypoint-initdb.d/*

			mysql_expire_root_user

			mysql_note "Stopping temporary server"
			docker_temp_server_stop
			mysql_note "Temporary server stopped"

			unset PASSFILE
			echo
			mysql_note "MySQL init process done. Ready for start up."
			echo
		fi
	fi
	exec "$@"
}

# This checks if the script has been sourced from elsewhere.
# If so we don't perform any further actions
# https://unix.stackexchange.com/a/215279
if [ "${FUNCNAME[${#FUNCNAME[@]} - 1]}" != 'source' ]; then
	_main "$@"
fi
