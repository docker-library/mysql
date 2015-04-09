FROM oraclelinux:latest

## -- The environment variables set using ENV will persist when a container
## -- is run from the resulting image. -- ##

ENV PACKAGE_URL http://repo.mysql.com/yum/mysql-5.7-community/docker/x86_64/mysql-community-server-minimal-5.7.7-0.3.rc.el7.x86_64.rpm

# Install server
RUN rpmkeys --import http://repo.mysql.com/RPM-GPG-KEY-mysql \
  && yum install -y $PACKAGE_URL \
  && rm -rf /var/cache/yum/*

VOLUME /var/lib/mysql

COPY docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 3306
CMD ["mysqld"]

