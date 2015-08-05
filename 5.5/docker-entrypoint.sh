#!/bin/bash
set -e

get_option () {
	local section=$1
	local option=$2
	local default=$3
	# my_print_defaults can output duplicates, if an option exists both globally and in
	# a custom config file. We pick the last occurence, which is from the custom config.
	ret=$(my_print_defaults $section | grep '^--'${option}'=' | cut -d= -f2- | tail -n1)
	[ -z $ret ] && ret=$default
	echo $ret
}

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
	set -- mysqld "$@"
fi

if [ "$1" = 'mysqld' ]; then
	# Get config
	DATADIR="$("$@" --verbose --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"
	SOCKET=$(get_option  mysqld socket "/tmp/mysql.sock")
	HOSTNAME=$(hostname)
	PIDFILE=$(get_option mysqld pid-file "$DATADIR/mysqld.pid")

	if [ ! -d "$DATADIR/mysql" ]; then
		if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" ]; then
			echo >&2 'error: database is uninitialized and MYSQL_ROOT_PASSWORD not set'
			echo >&2 '  Did you forget to add -e MYSQL_ROOT_PASSWORD=... ?'
			exit 1
		fi

		mkdir -p "$DATADIR"
		chown -R mysql:mysql "$DATADIR"

		echo 'Running mysql_install_db'
		mysql_install_db --user=mysql --datadir="$DATADIR" --rpm --basedir=/usr/local/mysql
		echo 'Finished mysql_install_db'

		mysqld --user=mysql --datadir="$DATADIR" --skip-networking --basedir=/usr/local/mysql --pid-file="$PIDFILE" &
		for i in $(seq 30 -1 0); do
			[ -S "$SOCKET" ] && break
			echo 'MySQL init process in progress...'
			sleep 1
		done
		if [ $i = 0 ]; then
			echo >&2 'MySQL init process failed.'
			exit 1
		fi

		mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql --protocol=socket -uroot mysql

		# These statements _must_ be on individual lines, and _must_ end with
		# semicolons (no line breaks or comments are permitted).
		# TODO proper SQL escaping on ALL the things D:

		tempSqlFile=$(mktemp /tmp/mysql-first-time.XXXXXX.sql)
		cat > "$tempSqlFile" <<-EOSQL
			-- What's done in this file shouldn't be replicated
			--  or products like mysql-fabric won't work
			SET @@SESSION.SQL_LOG_BIN=0;
			
			DELETE FROM mysql.user ;
			CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
			GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
			DROP DATABASE IF EXISTS test ;
		EOSQL

		# Create databases if specified on command line
                i=0
                while :
                do
                        if [ "$i" -eq "0" ]; then             # support "legacy" option before multiple database support
                                this_varname=MYSQL_DATABASE
                        else
                                this_varname=MYSQL_DATABASE$i
                        fi
                        thisdb=${!this_varname}
                        
			if [ "$thisdb" ]; then
                                echo "CREATE DATABASE IF NOT EXISTS \`$thisdb\` ;" >> "$tempSqlFile"
                        fi

                        # Yet another DB?
                        if [ "$thisdb" ] || [ "$i" -eq "0" ]; then
                                let ++i
                        else
                                break
                        fi
                done

                # Create users and grant them rights on the appropriate databases
                # If no number is used this user is granted rights on *all* DBs.
                if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
                        echo "CREATE USER '"$MYSQL_USER"'@'%' IDENTIFIED BY '"$MYSQL_PASSWORD"' ;" >> "$tempSqlFile"

                        i=0
                        while :
                        do
                                if [ "$i" -eq "0" ]; then             # support "legacy" option before multiple database support
                                        this_varname=MYSQL_DATABASE
                                else
                                        this_varname=MYSQL_DATABASE$i
                                fi

                                thisdb=${!this_varname}
                                if [ "$thisdb" ]; then
                                        echo "GRANT ALL ON \`"$thisdb"\`.* TO '"$MYSQL_USER"'@'%' ;" >> "$tempSqlFile"
                                fi

                                # Yet another DB?
                                if [ "$thisdb" ] || [ "$i" -eq "0" ]; then
                                        let ++i
                                else
                                        break
                                fi
                        done
                fi
		
		# If numbers are used on user specification they get rights on the database with the same number
                i=1
                while :
                do
			db_varname=MYSQL_DATABASE$i
			user_varname=MYSQL_USER$i
			pass_varname=MYSQL_PASSWORD$i

			db=${!db_varname}
			user=${!user_varname}
			pass=${!pass_varname}
			
			if [ "$user" -a "$pass" ]; then
				echo "CREATE USER '"$user"'@'%' IDENTIFIED BY '"$pass"' ;" >> "$tempSqlFile"
				if [ "$db" ]; then
					echo "GRANT ALL ON \`"$db"\`.* TO '"$user"'@'%' ;" >> "$tempSqlFile"	
				fi
			fi

			# Yet another user?
			if [ "$user" ] || [ "$pass" ] || [ "$db" ]; then
				let ++i
			else
				break
			fi
		done

		echo 'FLUSH PRIVILEGES ;' >> "$tempSqlFile"

		mysql --protocol=socket -uroot < "$tempSqlFile"

		rm -f "$tempSqlFile"
		kill $(cat $PIDFILE)
		for i in $(seq 30 -1 0); do
			[ -f "$PIDFILE" ] || break
			echo 'MySQL init process in progress...'
			sleep 1
		done
		if [ $i = 0 ]; then
			echo >&2 'MySQL hangs during init process.'
			exit 1
		fi
		echo 'MySQL init process done. Ready for start up.'
	fi

	chown -R mysql:mysql "$DATADIR"
fi

exec "$@"
