#!/bin/bash

VERSION=$1
echo "Running cleanup"
docker kill testserver
docker rm testserver
docker rmi "mysql/mysql-server:$VERSION"
echo "Cleanup complete"

