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
source VERSION
for MAJOR_VERSION in "${!MYSQL_SERVER_VERSIONS[@]}"; do
  docker build --build-arg http_proxy=$http_proxy --build-arg https_proxy=$http_proxy --build-arg no_proxy=$no_proxy -t mysql/mysql-server:$MAJOR_VERSION $MAJOR_VERSION
done
