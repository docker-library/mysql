#!/bin/bash
#
# Supported environment variables for this entrypoint:
#  - MYSQL_ROOT_PASSWORD
#  - MYSQL_REPLICA_USER: create the given user on the intended master host
#  - MYSQL_REPLICA_PASS
#  - MYSQL_MASTER_SERVER: change master on this location on the intended slave
#  - MYSQL_MASTER_PORT: optional, by default 3306
#  - MYSQL_MASTER_WAIT_TIME: seconds to wait for the master to come up
#
set -e

# TODO read this from the MySQL config?
DATADIR='/var/lib/mysql'

if [ "${1:0:1}" = '-' ]; then
	set -- mysqld "$@"
fi

if [ ! -d "$DATADIR/mysql" -a "${1%_safe}" = 'mysqld' ]; then
	if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" ]; then
		echo >&2 'error: database is uninitialized and MYSQL_ROOT_PASSWORD not set'
		echo >&2 '  Did you forget to add -e MYSQL_ROOT_PASSWORD=... ?'
		exit 1
	fi
	
	echo 'Running mysql_install_db ...'
	mysql_install_db
	echo 'Finished mysql_install_db'
	
	# These statements _must_ be on individual lines, and _must_ end with
	# semicolons (no line breaks or comments are permitted).
	# TODO proper SQL escaping on ALL the things D:
	
	tempSqlFile='/tmp/mysql-first-time.sql'
	cat > "$tempSqlFile" <<-EOSQL
		DELETE FROM mysql.user ;
		CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
		GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
		DROP DATABASE IF EXISTS test ;
	EOSQL
	
	if [ "$MYSQL_DATABASE" ]; then
		echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" >> "$tempSqlFile"
	fi
	
	if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
		echo "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;" >> "$tempSqlFile"
		
		if [ "$MYSQL_DATABASE" ]; then
			echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' ;" >> "$tempSqlFile"
		fi
	fi

	#
	# A replication user (actually created on both master and slaves)
	#
        if [ "$MYSQL_REPLICA_USER" ]; then
                if [ -z "$MYSQL_REPLICA_PASS" ]; then
                        echo >&2 'error: MYSQL_REPLICA_USER set, but MYSQL_REPLICA_PASS not set'
                        exit 1
                fi
                echo "CREATE USER '$MYSQL_REPLICA_USER'@'%' IDENTIFIED BY '$MYSQL_REPLICA_PASS'; " >> "$tempSqlFile"
                echo "GRANT REPLICATION SLAVE ON *.* TO '$MYSQL_REPLICA_USER'@'%'; " >> "$tempSqlFile"
                # REPLICATION CLIENT privileges are required to get master position
                echo "GRANT REPLICATION CLIENT ON *.* TO '$MYSQL_REPLICA_USER'@'%'; " >> "$tempSqlFile"
        fi

	#
	# On the slave: point to a master server
	#
        if [ "$MYSQL_MASTER_SERVER" ]; then
                MYSQL_MASTER_PORT=${MYSQL_MASTER_PORT:-3306}
		MYSQL_MASTER_WAIT_TIME=${MYSQL_MASTER_WAIT_TIME:-3}

                if [ -z "$MYSQL_REPLICA_USER" ]; then
                        echo >&2 'error: MYSQL_REPLICA_USER not set'
                        exit 1
                fi
                if [ -z "$MYSQL_REPLICA_PASS" ]; then
                        echo >&2 'error: MYSQL_REPLICA_PASS not set'
                        exit 1
                fi

		# Wait for eg. 10 seconds for the master to come up
		# do at least one iteration
		for i in $(seq $((MYSQL_MASTER_WAIT_TIME + 1))); do
			if ! mysql "-u$MYSQL_REPLICA_USER" "-p$MYSQL_REPLICA_PASS" "-h$MYSQL_MASTER_SERVER" -e 'select 1;' |grep -q 1; then
				echo >&2 "Waiting for $MYSQL_REPLICA_USER@$MYSQL_MASTER_SERVER"
				sleep 1
			else
				break
			fi
		done

		if [ "$i" -gt "$MYSQL_MASTER_WAIT_TIME" ]; then
			echo 2>&1 "Master is not reachable"
			exit 1
		fi

		# Get master position and set it on the slave. NB: MASTER_PORT and MASTER_LOG_POS must not be quoted
                MasterPosition=$(mysql "-u$MYSQL_REPLICA_USER" "-p$MYSQL_REPLICA_PASS" "-h$MYSQL_MASTER_SERVER" -e "show master status \G" | awk '/Position/ {print $2}')
                MasterFile=$(mysql  "-u$MYSQL_REPLICA_USER" "-p$MYSQL_REPLICA_PASS" "-h$MYSQL_MASTER_SERVER"   -e "show master status \G"     | awk '/File/ {print $2}')
                echo "CHANGE MASTER TO MASTER_HOST='$MYSQL_MASTER_SERVER', MASTER_PORT=$MYSQL_MASTER_PORT, MASTER_USER='$MYSQL_REPLICA_USER', MASTER_PASSWORD='$MYSQL_REPLICA_PASS', MASTER_LOG_FILE='$MasterFile', MASTER_LOG_POS=$MasterPosition;"  >> "$tempSqlFile"

		echo "START SLAVE;"  >> "$tempSqlFile"
        fi

	
	echo 'FLUSH PRIVILEGES ;' >> "$tempSqlFile"
	
	set -- "$@" --init-file="$tempSqlFile"
fi

chown -R mysql:mysql "$DATADIR"
exec "$@"
