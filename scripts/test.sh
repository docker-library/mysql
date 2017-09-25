#!/bin/bash

if [ ! -f "genOracleLinux.sh" ]; then
    echo "This script must be run from the base docker source directory"
    exit 1
fi
. VERSION

echo "...Starting images"

docker run -d --rm --name=mysqlserver55 --health-interval=5s -e MYSQL_ROOT_PASSWORD=rot mysql/mysql-server:5.5 > /dev/null
docker run -d --rm --name=mysqlserver56 --health-interval=5s -e MYSQL_ROOT_PASSWORD=rot mysql/mysql-server:5.6 > /dev/null
docker run -d --rm --name=mysqlserver57 --health-interval=5s -e MYSQL_ROOT_PASSWORD=rot mysql/mysql-server:5.7 > /dev/null
docker run -d --rm --name=mysqlserver80 --health-interval=5s -e MYSQL_ROOT_PASSWORD=rot mysql/mysql-server:8.0 > /dev/null

echo "...Waiting for health checks"
for i in {1..12}
do
    echo "."
    sleep 5
    if [ -z "$STATUS55" ];
    then
        if docker ps | grep mysqlserver55 | grep healthy | grep -v unhealthy > /dev/null; then
            echo "...MySQL 5.5 Image Started"
            if docker logs mysqlserver55 2>&1 | grep "MySQL Docker Image $VERSION_SERVER_55-$VERSION_DOCKER" > /dev/null; then
                RESPONSE=$(docker exec mysqlserver55 mysql -uroot -prot -e "SELECT VERSION();" 2>&1)
                if [[ "$RESPONSE" =~ "$VERSION_SERVER_55" ]];
                then
                    echo "...MySQL $VERSION_SERVER_55 OK"
                    STATUS55="OK"                
                else
                    echo "...Unexpected response from 5.5: $RESPONSE"
                    STATUS55=$RESPONSE
                    exit 1
                fi
            else
                echo "...Bad Docker script version"
                STATUS55="Incorrect Docker script version"
            fi
        fi
    fi
    if [ -z "$STATUS56" ];
    then
        if docker ps | grep mysqlserver56 | grep healthy | grep -v unhealthy > /dev/null; then
            echo "...MySQL 5.6 Image Started"
            if docker logs mysqlserver56 2>&1 | grep "MySQL Docker Image $VERSION_SERVER_56-$VERSION_DOCKER" > /dev/null; then
                RESPONSE=$(docker exec mysqlserver56 mysql -uroot -prot -e "SELECT VERSION();" 2>&1)
                if [[ "$RESPONSE" =~ "$VERSION_SERVER_56" ]];
                then
                    echo "...MySQL $VERSION_SERVER_56 OK"
                    STATUS56="OK"                
                else
                    echo "...Unexpected response from 5.6: $RESPONSE"
                    STATUS56=$RESPONSE
                    exit 1
                fi
            else
                echo "...Bad Docker script version"
                STATUS56="Incorrect Docker script version"
            fi
        fi
    fi
    if [ -z "$STATUS57" ];
    then
        if docker ps | grep mysqlserver57 | grep healthy | grep -v unhealthy > /dev/null; then
            echo "...MySQL 5.7 Image Started"
            if docker logs mysqlserver57 2>&1 | grep "MySQL Docker Image $VERSION_SERVER_57-$VERSION_DOCKER" > /dev/null; then
                RESPONSE=$(docker exec mysqlserver57 mysql -uroot -prot -e "SELECT VERSION();" 2>&1)
                if [[ "$RESPONSE" =~ "$VERSION_SERVER_57" ]];
                then
                    echo "...MySQL $VERSION_SERVER_57 OK"
                    RESPONSE=$(docker exec mysqlserver57 mysqlsh --version)
                    if [[ "$RESPONSE" =~ "$VERSION_SHELL_10" ]];
                    then
                        echo "...Shell $VERSION_SHELL_10 OK"
                        STATUS57="OK"                
                    else
                        echo "...Bad Shell version in 5.7 image"
                        STATUS57="$RESPONSE"
                    fi
                else
                    echo "...Unexpected response from 5.7: $RESPONSE"
                    STATUS57=$RESPONSE
                    exit 1
                fi
            else
                echo "...Bad Docker script version"
                STATUS57="Incorrect Docker script version"
            fi
        fi
    fi
    if [ -z "$STATUS80" ];
    then
        if docker ps | grep mysqlserver80 | grep healthy | grep -v unhealthy > /dev/null; then
            echo "...MySQL 8.0 Image Started"
            if docker logs mysqlserver80 2>&1 | grep "MySQL Docker Image $VERSION_SERVER_80-$VERSION_DOCKER" > /dev/null; then
                RESPONSE=$(docker exec mysqlserver80 mysql -uroot -prot -e "SELECT VERSION();" 2>&1)
                if [[ "$RESPONSE" =~ "$VERSION_SERVER_80" ]];
                then
                    echo "...MySQL $VERSION_SERVER_80 OK"
                    RESPONSE=$(docker exec mysqlserver80 mysqlsh --version)
                    if [[ "$RESPONSE" =~ "$VERSION_SHELL_80" ]];
                    then
                        echo "...Shell $VERSION_SHELL_80 OK"
                        STATUS80="OK"                
                    else
                        echo "...Bad Shell version in 5.7 image"
                        STATUS80="$RESPONSE"
                    fi
                    STATUS80="OK"                
                else
                    echo "...Unexpected response from 8.0: $RESPONSE"
                    STATUS80=$RESPONSE
                    exit 1
                fi
            else
                echo "...Bad Docker script version"
                STATUS80="Incorrect Docker script version"
            fi
        fi
    fi
    if [ -n "$STATUS55" ] && [ -n "$STATUS56" ] && [ -n "$STATUS57" ] && [ -n "$STATUS80" ];then
        break
    fi
done

echo "...Tests complete"
if [ "$STATUS55" = "OK" ] && [ "$STATUS56" = "OK" ] && [ "$STATUS57" = "OK" ] && [ "$STATUS80" = "OK" ];
then
    echo "...All tests OK. Cleaning up containers."
    docker kill mysqlserver55 mysqlserver56 mysqlserver57 mysqlserver80 > /dev/null
    exit 0
fi

echo "... There were test failures. Containers not removed."
echo "5.5: $STATUS55"
echo "5.6: $STATUS56"
echo "5.7: $STATUS57"
echo "8.0: $STATUS80"
