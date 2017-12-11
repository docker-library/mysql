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

# This script will simply use sed to replace placeholder variables in the
# files in template/ with version-specific variants.

VERSIONS="7.5 7.6"

. VERSION

declare -A SERVER_VERSION_FULL
SERVER_VERSION_FULL["7.5"]="${VERSION_CLUSTER_75}-${VERSION_DOCKER}"
SERVER_VERSION_FULL["7.6"]="${VERSION_CLUSTER_76}-dmr-${VERSION_DOCKER}"

declare -A PACKAGE_URL
PACKAGE_URL["7.5"]="https://dev.mysql.com/get/Downloads/MySQL-Cluster-7.5/mysql-cluster-community-server-minimal-7.5.9-1.el7.x86_64.rpm"
PACKAGE_URL["7.6"]="https://dev.mysql.com/get/Downloads/MySQL-Cluster-7.6/mysql-cluster-community-server-minimal-7.6.4-1.el7.x86_64.rpm"

declare -A PACKAGE_URL_SHELL
PACKAGE_URL_SHELL["7.5"]="https://repo.mysql.com/yum/mysql-tools-community/el/7/x86_64/mysql-shell-1.0.11-1.el7.x86_64.rpm"
PACKAGE_URL_SHELL["7.6"]="https://repo.mysql.com/yum/mysql-tools-preview/el/7/x86_64/mysql-shell-8.0.3-0.1.dmr.el7.x86_64.rpm"

declare -A PORTS
PORTS["7.5"]="3306 33060 2202 1186"
PORTS["7.6"]="3306 33060 2202 1186"

declare -A PASSWORDSET
PASSWORDSET["7.5"]="ALTER USER 'root'@'localhost' IDENTIFIED BY '\${MYSQL_ROOT_PASSWORD}';"
PASSWORDSET["7.6"]=${PASSWORDSET["7.5"]}

declare -A DATABASE_INIT
DATABASE_INIT["7.5"]="\"\$@\" --initialize-insecure"
DATABASE_INIT["7.6"]="\"\$@\" --initialize-insecure"

declare -A INIT_STARTUP
INIT_STARTUP["7.5"]="\"\$@\" --daemonize --skip-networking --socket=\"\$SOCKET\""
INIT_STARTUP["7.6"]="\"\$@\" --daemonize --skip-networking --socket=\"\$SOCKET\""

declare -A STARTUP_WAIT
STARTUP_WAIT["7.5"]="\"\""
STARTUP_WAIT["7.6"]="\"\""

declare -A EXPIRE_SUPPORT
EXPIRE_SUPPORT["7.5"]="\"yes\""
EXPIRE_SUPPORT["7.6"]="\"yes\""

# sed is for https://bugs.mysql.com/bug.php?id=20545
declare -A TZINFO_WORKAROUND
TZINFO_WORKAROUND["7.5"]=""
TZINFO_WORKAROUND["7.6"]=""

# Logging to console (stderr) makes server log available with the «docker logs command»
declare -A DEFAULT_LOG
DEFAULT_LOG["7.5"]="console"
DEFAULT_LOG["8.0"]="console"

for VERSION in ${VERSIONS}
do
  # Dockerfile
  sed 's#%%PACKAGE_URL%%#'"${PACKAGE_URL[${VERSION}]}"'#g' template/Dockerfile > tmpfile
  sed -i 's#%%PACKAGE_URL_SHELL%%#'"${PACKAGE_URL_SHELL[${VERSION}]}"'#g' tmpfile
  sed -i 's/%%PORTS%%/'"${PORTS[${VERSION}]}"'/g' tmpfile
  mv tmpfile ${VERSION}/Dockerfile

  # Entrypoint
  sed 's#%%PASSWORDSET%%#'"${PASSWORDSET[${VERSION}]}"'#g' template/docker-entrypoint.sh > tmpfile
  sed -i 's#%%DATABASE_INIT%%#'"${DATABASE_INIT[${VERSION}]}"'#g' tmpfile
  sed -i 's#%%EXPIRE_SUPPORT%%#'"${EXPIRE_SUPPORT[${VERSION}]}"'#g' tmpfile
  sed -i 's#%%SED_TZINFO%%#'"${TZINFO_WORKAROUND[${VERSION}]}"'#g' tmpfile
  sed -i 's#%%INIT_STARTUP%%#'"${INIT_STARTUP[${VERSION}]}"'#g' tmpfile
  sed -i 's#%%STARTUP_WAIT%%#'"${STARTUP_WAIT[${VERSION}]}"'#g' tmpfile
  sed -i 's#%%SERVER_VERSION_FULL%%#'"${SERVER_VERSION_FULL[${VERSION}]}"'#g' tmpfile
  sed -i 's#%%DEFAULT_LOG%%#'"${DEFAULT_LOG[${VERSION}]}"'#g' tmpfile
  mv tmpfile ${VERSION}/docker-entrypoint.sh
  chmod +x ${VERSION}/docker-entrypoint.sh

  # Healthcheck
  cp template/healthcheck.sh ${VERSION}/
  chmod +x ${VERSION}/healthcheck.sh

  # Config
  cp -r template/cnf ${VERSION}/
done
