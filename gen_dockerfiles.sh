#!/bin/bash
# Copyright (c) 2018, Oracle and/or its affiliates. All rights reserved.
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

set -e

function get_full_filename() {
        FILEPATH=$1
        PACKAGE_STRING=$2
        FILENAME=$(curl -s $FILEPATH/ | grep $PACKAGE_STRING | sed -e 's/.*href=\"//i' -e 's/\".*//')
        if [ -z "$FILENAME" ]; then
            echo &< "Unable to locate package for $PACKAGE_STRING. Aborting"
            exit 1
        fi
	COUNT=$(echo $FILENAME | tr " " "\n" | wc -l)
        if [ $COUNT -gt 1 ]; then
            echo &<2 "Found multiple file names for package $PACKAGE_STRING. Aborting"
            exit 1
        fi
	echo $FILENAME
}

if [ -z "$1" ]; then
  REPO=https://repo.mysql.com
else
  REPO=$1
fi

source VERSION

for MAJOR_VERSION in "${!MYSQL_CLUSTER_VERSIONS[@]}"
do
  # Dockerfile
  MYSQL_CLUSTER_REPOPATH=yum/mysql-cluster-$MAJOR_VERSION-community/docker/x86_64
  MYSQL_CLUSTER_PACKAGE_URL=$REPO/$MYSQL_CLUSTER_REPOPATH/$(get_full_filename $REPO/$MYSQL_CLUSTER_REPOPATH mysql-cluster-community-server-minimal-${MYSQL_CLUSTER_VERSIONS[${MAJOR_VERSION}]})
  sed 's#%%PACKAGE_URL%%#'"$MYSQL_CLUSTER_PACKAGE_URL"'#g' template/Dockerfile > tmpfile

  MYSQL_SHELL_REPOPATH=yum/mysql-tools-community/el/7/x86_64
  MYSQL_SHELL_PACKAGE_URL=$REPO/$MYSQL_SHELL_REPOPATH/$(get_full_filename $REPO/$MYSQL_SHELL_REPOPATH mysql-shell-${MYSQL_SHELL_VERSIONS[${MAJOR_VERSION}]})
  sed 's#%%MYSQL_CLUSTER_PACKAGE_URL%%#'"$MYSQL_CLUSTER_PACKAGE_URL"'#g' template/Dockerfile > tmpfile
  sed -i 's#%%MYSQL_SHELL_PACKAGE_URL%%#'"$MYSQL_SHELL_PACKAGE_URL"'#g' tmpfile

  mv tmpfile ${MAJOR_VERSION}/Dockerfile

  # Entrypoint
  sed 's#%%PASSWORDSET%%#'"${PASSWORDSET[${MAJOR_VERSION}]}"'#g' template/docker-entrypoint.sh > tmpfile
  sed -i 's#%%SERVER_VERSION_FULL%%#'"${SERVER_VERSION_FULL[${MAJOR_VERSION}]}"'#g' tmpfile
  mv tmpfile ${MAJOR_VERSION}/docker-entrypoint.sh
  chmod +x ${MAJOR_VERSION}/docker-entrypoint.sh

  # Healthcheck
  cp template/healthcheck.sh ${MAJOR_VERSION}/
  chmod +x ${MAJOR_VERSION}/healthcheck.sh

  # Config
  cp -r template/cnf ${MAJOR_VERSION}/
done
