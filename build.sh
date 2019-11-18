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
set -e
source ./VERSION

if grep -q Microsoft /proc/version; then
  echo "Running on Windows Subsystem for Linux"
  # WSL doesn't have its own docker host, we have to use the one 
  # from Windows itself.
  # https://medium.com/@sebagomez/installing-the-docker-client-on-ubuntus-windows-subsystem-for-linux-612b392a44c4
  export DOCKER_HOST=localhost:2375
fi

ARCH=amd64; [ -n "$1" ] && ARCH=$1
MAJOR_VERSIONS=("${!MYSQL_SERVER_VERSIONS[@]}"); [ -n "$2" ] && MAJOR_VERSIONS=("${@:2}")

for MAJOR_VERSION in "${MAJOR_VERSIONS[@]}"; do
  for MULTIARCH_VERSION in ${MULTIARCH_VERSIONS}; do
    if [[ "$MULTIARCH_VERSION" == "$MAJOR_VERSION" ]]; then
      docker build --build-arg http_proxy="$http_proxy" --build-arg https_proxy="$http_proxy" --build-arg no_proxy="$no_proxy" -t mysql/mysql-server:"$MAJOR_VERSION"-$ARCH "$MAJOR_VERSION"
    fi
  done
  for SINGLEARCH_VERSION in $SINGLEARCH_VERSIONS; do
    if [[ "$SINGLEARCH_VERSION" == "$MAJOR_VERSION" ]]; then
      docker build --build-arg http_proxy="$http_proxy" --build-arg https_proxy="$http_proxy" --build-arg no_proxy="$no_proxy" -t mysql/mysql-server:"$MAJOR_VERSION" "$MAJOR_VERSION"
    fi
  done
done
