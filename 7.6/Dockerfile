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

FROM oraclelinux:7-slim

ENV PACKAGE_URL http://repo.mysql.com/yum/mysql-cluster-7.6-community/docker/x86_64/mysql-cluster-community-server-minimal-7.6.2-1.el7.x86_64.rpm

RUN	yum install -y $PACKAGE_URL && \
	rm -rf /var/cache/yum/* && \
	chown -R mysql:mysql /var/lib/mysql

VOLUME /var/lib/mysql

COPY docker-entrypoint.sh /entrypoint.sh
COPY cnf/my.cnf /etc/
COPY cnf/mysql-cluster.cnf /etc/
ENTRYPOINT ["/entrypoint.sh"]
EXPOSE 3306 2202 1186

CMD ["ndb_mgm"]
