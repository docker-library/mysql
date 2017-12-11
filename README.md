![logo](https://www.mysql.com/common/logos/logo-mysql-170x115.png)

What is MySQL?
--------------

MySQL is the world's most popular open source database. With its proven performance, reliability, and ease-of-use, MySQL has become the leading choice of database for web applications of all sorts, ranging from personal websites and small online shops all the way to large-scale, high profile web operations like Facebook, Twitter, and YouTube.

For more information and related downloads for MySQL Server and other MySQL products, please visit <http://www.mysql.com>.

Supported Tags and Respective Dockerfile Links
----------------------------------------------

These are tags for some of the optimized MySQL Server Docker images, created and maintained by the MySQL team at Oracle (for a full list, see [the Tags tab of this page](https://hub.docker.com/r/mysql/mysql-server/tags/)).

-   MySQL Server 5.5 (tag: [`5.5`, `5.5.58`, `5.5.58-1.1.2`](https://github.com/mysql/mysql-docker/blob/mysql-server/5.5/Dockerfile)) ([mysql-server/5.5/Dockerfile](https://github.com/mysql/mysql-docker/blob/mysql-server/5.5/Dockerfile))

-   MySQL Server 5.6 (tag: [`5.6`, `5.6.38`, `5.6.38-1.1.2`](https://github.com/mysql/mysql-docker/blob/mysql-server/5.6/Dockerfile)) ([mysql-server/5.6/Dockerfile](https://github.com/mysql/mysql-docker/blob/mysql-server/5.6/Dockerfile))

-   MySQL Server 5.7, the latest GA (tag: [`5.7`, `5.7.20`, `5.7.20-1.1.2`](https://github.com/mysql/mysql-docker/blob/mysql-server/5.7/Dockerfile)) ([mysql-server/5.7/Dockerfile](https://github.com/mysql/mysql-docker/blob/mysql-server/5.7/Dockerfile))

-   MySQL Server 8.0, Release Candidate (tag: [`8.0`, `8.0.3-rc`, `8.0.3-rc-1.1.2`](https://github.com/mysql/mysql-docker/blob/mysql-server/8.0/Dockerfile)) ([mysql-server/8.0/Dockerfile](https://github.com/mysql/mysql-docker/blob/mysql-server/8.0/Dockerfile))

Images are updated when new MySQL Server maintenance releases and development milestones are published. Please note that non-GA releases are for preview purposes only and should not be used in production setups.

We also from time to time publish special MySQL Server images that contain experimental features. Please take a look at the [MySQL Docker image list](https://hub.docker.com/r/mysql/) to see what are available.

Quick Reference
---------------

-   *Detailed documentation:* See [Deploying MySQL on Linux with Docker](https://dev.mysql.com/doc/refman/5.7/en/linux-installation-docker.html) in the [MySQL Reference Manual](https://dev.mysql.com/doc/refman/5.7/en/).

-   *Where to file issues:* Please submit a bug report at <http://bugs.mysql.com> under the category “MySQL Package Repos and Docker Images”.

-   *Maintained by:* The MySQL team at Oracle

-   *Source of this image:* The [Image repository for the `mysql/mysql-server` container](https://github.com/mysql/mysql-docker)

-   *Supported Docker versions:* The latest stable release is supported. Support for older versions (down to 1.0) is provided on a best-effort basis, but we strongly recommend using the most recent stable Docker version, which this documentation assumes.

How to Use the MySQL Images
---------------------------

### Downloading a MySQL Server Docker Image

Downloading the server image in a separate step is not strictly necessary; however, performing this before you create your Docker container ensures your local image is up to date.

To download the MySQL Community Edition image, run this command:

    docker pull mysql/mysql-server:tag
                
             

Refer to the list of supported tags above. If `:tag
            ` is omitted, the `latest` tag is used, and the image for the latest GA version of MySQL Server is downloaded.

### Starting a MySQL Server Instance

Start a new Docker container for the MySQL Community Server with this command:

    docker run --name=mysql1 -d mysql/mysql-server:tag
                 
             

The `--name` option, for supplying a custom name for your server container (`mysql1` in the example), is optional; if no container name is supplied, a random one is generated. If the Docker image of the specified name and tag has not been downloaded by an earlier `docker pull` or `docker run` command, the image is now downloaded. After download completes, initialization for the container begins, and the container appears in the list of running containers when you run the `docker ps` command; for example:

    shell> docker ps
    CONTAINER ID   IMAGE                COMMAND                  CREATED             STATUS                              PORTS                NAMES
    a24888f0d6f4   mysql/mysql-server   "/entrypoint.sh my..."   14 seconds ago      Up 13 seconds (health: starting)    3306/tcp, 33060/tcp  mysql1 

The container initialization might take some time. When the server is ready for use, the `STATUS` of the container in the output of the `docker ps` command changes from `(health: starting)` to `(healthy)`.

The `-d` option used in the `docker
        run` command above makes the container run in the background. Use this command to monitor the output from the container:

       docker logs mysql1
                

Once initialization is finished, the command's output is going to contain the random password generated for the root user; check the password with, for example, this command:

    shell> docker logs mysql1 2>&1 | grep GENERATED
    GENERATED ROOT PASSWORD: Axegh3kAJyDLaRuBemecis&EShOs

### Connecting to MySQL Server from within the Container

Once the server is ready, you can run the `mysql` client within the MySQL Server container you just started and connect it to the MySQL Server. Use the `docker exec -it` command to start a `mysql` client inside the Docker container you have started, like this:

       docker exec -it mysql1 mysql -uroot -p
                

When asked, enter the generated root password (see the instructions above on how to find it). Because the `MYSQL_ONETIME_PASSWORD` option is true by default, after you started the server container with the sample command above and connected a `mysql` client to the server, you must reset the server root password by issuing this statement:

    mysql> ALTER USER 'root'@'localhost' IDENTIFIED BY 'newpassword';
                

Substitute `newpassword` with the password of your choice. Once the password is reset, the server is ready for use.

### Container Shell Access

To have shell access to your MySQL Server container, use the `docker exec -it` command to start a bash shell inside the container:

    shell> docker exec -it mysql1 bash 
    bash-4.2#    

You can then run Linux commands inside the container at the bash prompt.

### Stopping and Deleting a MySQL Container

To stop the MySQL Server container we have created, use this command:

    docker stop mysql1
             

`docker stop` sends a SIGTERM signal to the `mysqld` process, so that the server is shut down gracefully.

Also notice that when the main process of a container (`mysqld` in the case of a MySQL Server container) is stopped, the Docker container stops automatically.

To start the MySQL Server container again:

    docker start mysql1
             

To stop and start again the MySQL Server container with a single command:

    docker restart mysql1
             

To delete the MySQL container, stop it first, and then use the `docker rm` command:

    docker stop mysql1
             
    docker rm mysql1 
             

If you want the [Docker volume for the server's data directory](https://dev.mysql.com/doc/refman/5.7/en/docker-mysql-more-topics.html#docker-persisting-data-configuration) to be deleted at the same time, add the `-v` option to the `docker rm` command.

### More Topics on Deploying MySQL Server with Docker

For more topics on deploying MySQL Server with Docker like server configuration, persisting data and configuration, and server error log, see [More Topics on Deploying MySQL Server with Docker](https://dev.mysql.com/doc/refman/5.7/en/docker-mysql-more-topics.html) in the MySQL Server manual.

Docker Environment Variables
----------------------------

When you create a MySQL Server container, you can configure the MySQL instance by using the `--env` option (`-e` in short) and specifying one or more of the following environment variables.

> **Notes**
>
> -   None of the variables below has any effect if you mount a data directory that is not empty, as no server initialization is going to be attempted then (see [Persisting Data and Configuration Changes](https://dev.mysql.com/doc/refman/5.7/en/docker-mysql-more-topics.html#docker-persisting-data-configuration) for more details). Any pre-existing contents in the folder, including any old server settings, are not modified during the container startup.
>
> -   The boolean variables including `MYSQL_RANDOM_ROOT_PASSWORD`, `MYSQL_ONETIME_PASSWORD`, `MYSQL_ALLOW_EMPTY_PASSWORD`, and `MYSQL_LOG_CONSOLE` are made true by setting them with any strings of non-zero lengths. Therefore, setting them to, for example, “0”, “false”, or “no” does not make them false, but actually makes them true. This is a known issue of the MySQL Server containers.
>
&nbsp;

-   `MYSQL_RANDOM_ROOT_PASSWORD`: When this variable is true (which is its default state, unless `MYSQL_ROOT_PASSWORD` is set or `MYSQL_ALLOW_EMPTY_PASSWORD` is set to true), a random password for the server's root user is generated when the Docker container is started. The password is printed to `stdout` of the container and can be found by looking at the container’s log.

-   `MYSQL_ONETIME_PASSWORD`: When the variable is true (which is its default state, unless `MYSQL_ROOT_PASSWORD` is set or `MYSQL_ALLOW_EMPTY_PASSWORD` is set to true), the root user's password is set as expired and must be changed before MySQL can be used normally. This variable is only supported for MySQL 5.6 and later.

-   `MYSQL_DATABASE`: This variable allows you to specify the name of a database to be created on image startup. If a user name and a password are supplied with `MYSQL_USER` and `MYSQL_PASSWORD`, the user is created and granted superuser access to this database (corresponding to `GRANT ALL`). The specified database is created by a [CREATE DATABASE IF NOT EXIST](#create-database) statement, so that the variable has no effect if the database already exists.

-   `MYSQL_USER`, `MYSQL_PASSWORD`: These variables are used in conjunction to create a user and set that user's password, and the user is granted superuser permissions for the database specified by the `MYSQL_DATABASE` variable. Both `MYSQL_USER` and `MYSQL_PASSWORD` are required for a user to be created; if any of the two variables is not set, the other is ignored. If both variables are set but `MYSQL_DATABASE` is not, the user is created without any privileges.

    > **Note**
    >
    > There is no need to use this mechanism to create the root superuser, which is created by default with the password set by either one of the mechanisms discussed in the descriptions for `MYSQL_ROOT_PASSWORD` and `MYSQL_RANDOM_ROOT_PASSWORD`, unless `MYSQL_ALLOW_EMPTY_PASSWORD` is true.

-   `MYSQL_ROOT_HOST`: By default, MySQL creates the `'root'@'localhost'` account. This account can only be connected to from inside the container. To allow root connections from other hosts, set this environment variable. For example, the value `172.17.0.1`, which is the default Docker gateway IP, allows connections from the host machine that runs the container. The option accepts only one entry, but wildcards are allowed (for example, `MYSQL_ROOT_HOST=172.*.*.*` or `MYSQL_ROOT_HOST=%`).

-   `MYSQL_LOG_CONSOLE`: When the variable is true (which is its default state for MySQL 8.0 server containers), the MySQL Server's error log is redirected to `stderr`, so that the error log goes into the Docker container's log and is viewable using the `docker logs` command.

    > **Note**
    >
    > The variable has no effect if a server configuration file from the host has been mounted (see [Persisting Data and Configuration Changes](https://dev.mysql.com/doc/refman/5.7/en/docker-mysql-more-topics.html#docker-persisting-data-configuration) on bind-mounting a configuration file).

-   `MYSQL_ROOT_PASSWORD`: This variable specifies a password that is set for the MySQL root account.

    > **Warning**
    >
    > Setting the MySQL root user password on the command line is insecure. As an alternative to specifying the password explicitly, you can set the variable with a container file path for a password file, and then mount a file from your host that contains the password at the container file path. This is still not very secure, as the location of the password file is still exposed. It is preferable to use the default settings of `MYSQL_RANDOM_ROOT_PASSWORD` and `MYSQL_ONETIME_PASSWORD` being both true.

-   `MYSQL_ALLOW_EMPTY_PASSWORD`. Set it to true to allow the container to be started with a blank password for the root user.

    > **Warning**
    >
    > Setting this variable to true is insecure, because it is going to leave your MySQL instance completely unprotected, allowing anyone to gain complete superuser access. It is preferable to use the default settings of `MYSQL_RANDOM_ROOT_PASSWORD` and `MYSQL_ONETIME_PASSWORD` being both true.
