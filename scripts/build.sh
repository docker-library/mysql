#!/bin/bash

set -e

if [ ! -f "genOracleLinux.sh" ]; then
    echo "This script must be run from the base docker source directory"
    exit 1
fi
. VERSION

echo "Docker image version: $VERSION_DOCKER"
echo "The following server versions will be packaged:"
echo " - $VERSION_SERVER_55"
echo " - $VERSION_SERVER_56"
echo " - $VERSION_SERVER_57"
echo " - $VERSION_SERVER_80"
echo "The following shell versions will be packaged:"
echo " - For 5.7: $VERSION_SHELL_10"
echo " - For 8.0: $VERSION_SHELL_80"
read -p "Is this correct? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Aborting"
    exit 0
fi

echo "...Locating server packages"

for VERSION_SERVER in $VERSION_SERVER_55 $VERSION_SERVER_56 $VERSION_SERVER_57 $VERSION_SERVER_80
do
    VERSION_PART=${VERSION_SERVER:0:3}
    REPOURL=https://repo.mysql.com/yum/mysql-$VERSION_PART-community/docker/x86_64/
    FILENAME=$(wget -q -O - $REPOURL | grep mysql-community-server-minimal-$VERSION_SERVER | cut -d \" -f 6 | sort -r | head -1)
    if [ -z "$FILENAME" ];
    then
        echo "Unable to locate server package for $VERSION_SERVER. Aborting"
        exit 1
    fi
    sed -i "s#^PACKAGE_URL\[\"${VERSION_PART}\"\].*#PACKAGE_URL\[\"${VERSION_PART}\"\]=\"${REPOURL}${FILENAME}\"#" genOracleLinux.sh 
done

echo "...Locating shell packages"

REPOURL_SHELL_10="https://repo.mysql.com/yum/mysql-tools-community/el/7/x86_64/"
REPOURL_SHELL_80="https://repo.mysql.com/yum/mysql-tools-preview/el/7/x86_64/"
FILENAME_SHELL_10=$(wget -q -O - $REPOURL_SHELL_10 | grep mysql-shell-$VERSION_SHELL_10 | cut -d \" -f 6 | sort -r | head -1)
FILENAME_SHELL_80=$(wget -q -O - $REPOURL_SHELL_80 | grep mysql-shell-$VERSION_SHELL_80 | cut -d \" -f 6 | sort -r | head -1)
if [ -z "$FILENAME_SHELL_10" ];
then
    echo "Unable to locate shell package for $VERSION_SHELL_10. Aborting."
    exit 1
fi
if [ -z "$FILENAME_SHELL_80" ];
then
    echo "Unable to locate shell package for $VERSION_SHELL_80. Aborting."
    exit 1
fi
sed -i "s#^PACKAGE_URL_SHELL\[\"5.7\"\].*#PACKAGE_URL_SHELL\[\"5.7\"\]=\"${REPOURL_SHELL_10}${FILENAME_SHELL_10}\"#" genOracleLinux.sh 
sed -i "s#^PACKAGE_URL_SHELL\[\"8.0\"\].*#PACKAGE_URL_SHELL\[\"8.0\"\]=\"${REPOURL_SHELL_80}${FILENAME_SHELL_80}\"#" genOracleLinux.sh 
echo "...Generating image source"
./genOracleLinux.sh

echo "...Building Docker images"
for MAJOR_VERSION in 5.5 5.6 5.7 8.0
do
    echo "...$MAJOR_VERSION"
    if [ -n "$http_proxy" ] && [ -n "$https_proxy" ];
    then
        docker build -t mysql/mysql-server:$MAJOR_VERSION --build-arg http_proxy=$http_proxy --build-arg https_proxy=$https_proxy $MAJOR_VERSION 2>&1>buildlog.txt
    else
        docker build -t mysql/mysql-server:$MAJOR_VERSION $MAJOR_VERSION 2>&1>buildlog.txt
    fi
done
