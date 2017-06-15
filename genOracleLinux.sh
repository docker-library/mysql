#!/bin/bash
# Copyright (c) 2017, Oracle and/or its affiliates. All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA
VERSIONS="5.5 5.6 5.7 8.0"

declare -A PACKAGE_URL
PACKAGE_URL["5.5"]="https://repo.mysql.com/yum/mysql-5.5-community/docker/x86_64/mysql-community-server-minimal-5.5.55-2.el7.x86_64.rpm"
PACKAGE_URL["5.6"]="https://repo.mysql.com/yum/mysql-5.6-community/docker/x86_64/mysql-community-server-minimal-5.6.36-2.el7.x86_64.rpm"
PACKAGE_URL["5.7"]="https://repo.mysql.com/yum/mysql-5.7-community/docker/x86_64/mysql-community-server-minimal-5.7.18-1.el7.x86_64.rpm"
PACKAGE_URL["8.0"]="https://repo.mysql.com/yum/mysql-8.0-community/docker/x86_64/mysql-community-server-minimal-8.0.1-0.1.dmr.el7.x86_64.rpm"

# 33060 is the default port for the mysqlx plugin, new to 5.7
declare -A PORTS
PORTS["5.5"]="3306"
PORTS["5.6"]="3306"
PORTS["5.7"]="3306 33060"
PORTS["8.0"]="3306 33060"

declare -A PASSWORDSET
PASSWORDSET["5.5"]="SET PASSWORD FOR 'root'@'localhost'=PASSWORD('\${MYSQL_ROOT_PASSWORD}');"
PASSWORDSET["5.6"]=${PASSWORDSET["5.5"]}
PASSWORDSET["5.7"]="ALTER USER 'root'@'localhost' IDENTIFIED BY '\${MYSQL_ROOT_PASSWORD}';"
PASSWORDSET["8.0"]=${PASSWORDSET["5.7"]}

declare -A DATABASE_INIT
DATABASE_INIT["5.5"]="mysql_install_db --user=mysql --datadir=\"\$DATADIR\" --rpm"
DATABASE_INIT["5.6"]="mysql_install_db --user=mysql --datadir=\"\$DATADIR\" --rpm --keep-my-cnf"
DATABASE_INIT["5.7"]="\"\$@\" --initialize-insecure"
DATABASE_INIT["8.0"]="\"\$@\" --initialize-insecure"

# 5.7+ has the --daemonize flag, which makes the process fork and then exit when
# the server is ready, removing the need for a fragile wait loop
declare -A INIT_STARTUP
INIT_STARTUP["5.5"]="\"\$@\" --skip-networking --socket=/var/run/mysqld/mysqld.sock \&"
INIT_STARTUP["5.6"]="\"\$@\" --skip-networking --socket=/var/run/mysqld/mysqld.sock \&"
INIT_STARTUP["5.7"]="\"\$@\" --daemonize --skip-networking --socket=/var/run/mysqld/mysqld.sock"
INIT_STARTUP["8.0"]="\"\$@\" --daemonize --skip-networking --socket=/var/run/mysqld/mysqld.sock"

declare -A STARTUP_WAIT
STARTUP_WAIT["5.5"]="\"yes\""
STARTUP_WAIT["5.6"]="\"yes\""
STARTUP_WAIT["5.7"]="\"\""
STARTUP_WAIT["8.0"]="\"\""

# The option to set a user as expired, (forcing a password change before
# any other action can be taken) was added in 5.6
declare -A EXPIRE_SUPPORT
EXPIRE_SUPPORT["5.5"]="\"\""
EXPIRE_SUPPORT["5.6"]="\"yes\""
EXPIRE_SUPPORT["5.7"]="\"yes\""
EXPIRE_SUPPORT["8.0"]="\"yes\""

# sed is for https://bugs.mysql.com/bug.php?id=20545
declare -A TZINFO_WORKAROUND
TZINFO_WORKAROUND["5.5"]="sed 's/Local time zone must be set--see zic manual page/FCTY/' | "
TZINFO_WORKAROUND["5.6"]="sed 's/Local time zone must be set--see zic manual page/FCTY/' | "
TZINFO_WORKAROUND["5.7"]=""
TZINFO_WORKAROUND["8.0"]=""

for VERSION in ${VERSIONS}
do
  # Dockerfile
  sed 's#%%PACKAGE_URL%%#'"${PACKAGE_URL[${VERSION}]}"'#g' template/Dockerfile > tmpfile
  sed -i 's/%%PORTS%%/'"${PORTS[${VERSION}]}"'/g' tmpfile
  mv tmpfile ${VERSION}/Dockerfile

  # Entrypoint
  sed 's#%%PASSWORDSET%%#'"${PASSWORDSET[${VERSION}]}"'#g' template/docker-entrypoint.sh > tmpfile
  sed -i 's#%%DATABASE_INIT%%#'"${DATABASE_INIT[${VERSION}]}"'#g' tmpfile
  sed -i 's#%%EXPIRE_SUPPORT%%#'"${EXPIRE_SUPPORT[${VERSION}]}"'#g' tmpfile
  sed -i 's#%%SED_TZINFO%%#'"${TZINFO_WORKAROUND[${VERSION}]}"'#g' tmpfile
  sed -i 's#%%INIT_STARTUP%%#'"${INIT_STARTUP[${VERSION}]}"'#g' tmpfile
  sed -i 's#%%STARTUP_WAIT%%#'"${STARTUP_WAIT[${VERSION}]}"'#g' tmpfile
  mv tmpfile ${VERSION}/docker-entrypoint.sh
done
