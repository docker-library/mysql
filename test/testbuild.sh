#!/bin/bash

VERSION=$1
DIRECTORY=$2

echo "Building image mysql/mysql-server:$VERSION"
docker build -t mysql/mysql-server:$VERSION $DIRECTORY
RES=$?
if [ $RES -eq 0 ]; 
then
	echo "Image built"
else
	echo "Image build failed"
	exit 0
fi

	
IMAGELIST=$(docker images | grep $VERSION)
versionregex="mysql/mysql-server\s*$VERSION"
if [[ $IMAGELIST =~ $versionregex ]];
then
	echo "Test passed"
	exit 0
else
	echo "Test failed. Image not in list"
	exit 1
fi


