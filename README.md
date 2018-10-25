![logo](https://www.mysql.com/common/logos/logo-mysql-170x115.png)

What is MySQL?
--------------

MySQL is the world's most popular open source database. With its proven performance, reliability, and ease-of-use, MySQL has become the leading choice of database for web applications of all sorts, ranging from personal websites and small online shops all the way to large-scale, high profile web operations like Facebook, Twitter, and YouTube.

For more information and related downloads for MySQL Server and other MySQL products, please visit <http://www.mysql.com>.

Supported Tags and Respective Dockerfile Links
----------------------------------------------

> **Warning**
>
> The MySQL Docker images maintained by the MySQL team are built specifically for Linux platforms. Other platforms are not supported, and users using these MySQL Docker images on them are doing so at their own risk. See [the discussion here](https://dev.mysql.com/doc/refman/8.0/en/deploy-mysql-nonlinux-docker.html) for some known limitations for running these containers on non-Linux operating systems.

These are tags for some of the optimized MySQL Server Docker images, created and maintained by the MySQL team at Oracle (for a full list, see [the Tags tab of this page](https://hub.docker.com/r/mysql/mysql-server/tags/)). [DS] The tags are updated directly on the posted Markdown versions by RE after eahc release, so it might remain outdated in this DocBook source file.

-   MySQL Server 5.5 (tag: [`5.5`, `5.5.62`, `5.5.62-1.1.8`](https://github.com/mysql/mysql-docker/blob/mysql-server/5.5/Dockerfile)) ([mysql-server/5.5/Dockerfile](https://github.com/mysql/mysql-docker/blob/mysql-server/5.5/Dockerfile))

-   MySQL Server 5.6 (tag: [`5.6`, `5.6.42`, `5.6.42-1.1.8`](https://github.com/mysql/mysql-docker/blob/mysql-server/5.6/Dockerfile)) ([mysql-server/5.6/Dockerfile](https://github.com/mysql/mysql-docker/blob/mysql-server/5.6/Dockerfile))

-   MySQL Server 5.7 (tag: [`5.7`, `5.7.24`, `5.7.24-1.1.8`](https://github.com/mysql/mysql-docker/blob/mysql-server/5.7/Dockerfile)) ([mysql-server/5.7/Dockerfile](https://github.com/mysql/mysql-docker/blob/mysql-server/5.7/Dockerfile))

-   MySQL Server 8.0, the latest GA (tag: [`8.0`, `8.0.13`, `8.0.13-1.1.8`, `latest`](https://github.com/mysql/mysql-docker/blob/mysql-server/8.0/Dockerfile)) ([mysql-server/8.0/Dockerfile](https://github.com/mysql/mysql-docker/blob/mysql-server/8.0/Dockerfile))

-   MySQL Server 8.0 is also available for AArch64 (ARM64), using the same tags.

Images are updated when new MySQL Server maintenance releases and development milestones are published. Please note that any non-GA releases are for preview purposes only and should not be used in production setups.

We also from time to time publish special MySQL Server images that contain experimental features.

Quick Reference
---------------

-   *Detailed documentation:* See [Deploying MySQL on Linux with Docker](https://dev.mysql.com/doc/refman/8.0/en/linux-installation-docker.html) in the [MySQL Reference Manual](https://dev.mysql.com/doc/refman/8.0/en/).

-   *Where to file issues:* Please submit a bug report at <http://bugs.mysql.com> under the category “MySQL Package Repos and Docker Images”.

-   *Maintained by:* The MySQL team at Oracle

-   *Source of this image:* The [Image repository for the `mysql/mysql-server` container](https://github.com/mysql/mysql-docker)

-   *Supported Docker versions:* The latest stable release is supported. Support for older versions (down to 1.0) is provided on a best-effort basis, but we strongly recommend using the most recent stable Docker version, which this documentation assumes.

How to Use the MySQL Images
---------------------------

### Downloading a MySQL Server Docker Image

Downloading the server image in a separate step is not strictly necessary; however, performing this before you create your Docker container ensures your local image is up to date.

To download the MySQL Community Edition image, run this command:

    shell> docker pull mysql/mysql-server:tag
&nbsp;
Refer to the list of supported tags above. If `:tag
            ` is omitted, the `latest` tag is used, and the image for the latest GA version of MySQL Server is downloaded.

### Starting a MySQL Server Instance

Start a new Docker container for the MySQL Community Server with this command:

    shell> docker run --name=mysql1 -d mysql/mysql-server:tag
&nbsp;
The `--name` option, for supplying a custom name for your server container (`mysql1` in the example), is optional; if no container name is supplied, a random one is generated. If the Docker image of the specified name and tag has not been downloaded by an earlier `docker pull` or `docker run` command, the image is now downloaded. After download completes, initialization for the container begins, and the container appears in the list of running containers when you run the `docker ps` command; for example:

    shell> docker ps
    CONTAINER ID   IMAGE                COMMAND                  CREATED             STATUS                              PORTS                NAMES
    a24888f0d6f4   mysql/mysql-server   "/entrypoint.sh my..."   14 seconds ago      Up 13 seconds (health: starting)    3306/tcp, 33060/tcp  mysql1
&nbsp;             
The container initialization might take some time. When the server is ready for use, the `STATUS` of the container in the output of the `docker ps` command changes from `(health: starting)` to `(healthy)`.

The `-d` option used in the `docker
        run` command above makes the container run in the background. Use this command to monitor the output from the container:

    shell> docker logs mysql1
&nbsp;
Once initialization is finished, the command's output is going to contain the random password generated for the root user; check the password with, for example, this command:

    shell> docker logs mysql1 2>&1 | grep GENERATED
    GENERATED ROOT PASSWORD: Axegh3kAJyDLaRuBemecis&EShOs
&nbsp;
### Connecting to MySQL Server from within the Container

Once the server is ready, you can run the `mysql` client within the MySQL Server container you just started and connect it to the MySQL Server. Use the `docker exec -it` command to start a `mysql` client inside the Docker container you have started, like this:

    shell> docker exec -it mysql1 mysql -uroot -p
&nbsp;
When asked, enter the generated root password (see the instructions above on how to find it). Because the `MYSQL_ONETIME_PASSWORD` option is true by default, after you have connected a `mysql` client to the server, you must reset the server root password by issuing this statement:

    mysql> ALTER USER 'root'@'localhost' IDENTIFIED BY 'password';
&nbsp;
Substitute `password` with the password of your choice. Once the password is reset, the server is ready for use.

### Products Included in the Container

A number of MySQL products are included in the Docker container you created with the MySQL Server Docker image:

-   MySQL Server and other MySQL Programs including the [mysql](https://dev.mysql.com/doc/refman/8.0/en/mysql.html) client,[mysqladmin](https://dev.mysql.com/doc/refman/8.0/en/mysqladmin.html), [mysqldump](https://dev.mysql.com/doc/refman/8.0/en/mysqldump.html), and so on. See the [MySQL Reference Manual](https://dev.mysql.com/doc/refman/8.0/en/programs-overview.html) for documentation of the products.

-   MySQL Shell. See the [MySQL Shell User Guide](https://dev.mysql.com/doc/refman/8.0/en/mysql-shell.html) for documentation of the product.

### More Topics on Deploying MySQL Server with Docker

For more topics on deploying MySQL Server with Docker like starting and connecting to the server, server configuration, persisting data and configuration, server error log, server upgrades, and the Docker environment variables, see [Deploying MySQL Server with Docker](https://dev.mysql.com/doc/refman/8.0/en/linux-installation-docker.html) in the MySQL Server manual.
