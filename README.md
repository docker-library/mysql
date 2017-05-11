![logo](https://www.mysql.com/common/logos/logo-mysql-170x115.png)

# What is MySQL?

MySQL is the world's most popular open source database. With its proven performance, reliability and ease-of-use, MySQL has become the leading database choice for web-based applications, covering the entire range from personal projects and websites, via online shops and information services, all the way to high profile web properties including Facebook, Twitter, YouTube, Yahoo! and many more.

For more information and related downloads for MySQL Server and other MySQL products, please visit http://www.mysql.com.

# What is  MySQL Cluster?

MySQL Cluster is built on the NDB storage engine and provides a highly scalable, real-time, ACID-compliant transactional database, combining 99.999% availability with the low TCO of open source. Designed around a distributed, multi-master architecture with no single point of failure, MySQL Cluster scales horizontally on commodity hardware to serve read and write intensive workloads, accessed via SQL and NoSQL interfaces.

For more information about MySQL Cluster, please visit https://www.mysql.com/products/cluster/

# MySQL Cluster Docker Images

These are optimized MySQL Cluster Docker images, created and maintained by the MySQL team at Oracle. The available versions are:

    MySQL Cluster 7.5, the latest GA version (tag: 7.5 or latest)
    MySQL Cluster 7.6, preview release (tag: 7.6)

Images are updated when new MySQL Cluster maintenance releases and development milestones are published. Please note that all MySQL Cluster Docker images are to be considered experiemental and should not be used in production.

# How to Use the MySQL Cluster Images

## Start a MySQL Cluster Using Default Configuration

Note that the ordering of container startup is very strict, and will likely need to be started from scratch if any step fails
First we create an internal Docker network that the containers will use to communicate

    docker network create cluster --subnet=192.168.0.0/16

Then we start the management node

    docker run -d --net=cluster --name=management1 --ip=192.168.0.2 mysql/mysql-cluster ndb_mgmd

The two data nodes

    docker run -d --net=cluster --name=ndb1 --ip=192.168.0.3 mysql/mysql-cluster ndbd
    docker run -d --net=cluster --name=ndb2 --ip=192.168.0.4 mysql/mysql-cluster ndbd

And finally the MySQL server node

    docker run -d --net=cluster --name=mysql1 --ip=192.168.0.10 mysql/mysql-cluster mysqld

The server will be initialized with a randomized password that will need to be changed, so fetch it from the log, then log in and change the password.
If you get an error saying «ERROR 2002 (HY000): Can't connect to local MySQL server through socket» then the server has not finished initializing yet.

    docker logs mysql1 2>&1 | grep password
    docker exec -it mysql1 mysql -uroot -p
    ALTER USER 'root'@'localhost' IDENTIFIED BY 'MyNewPass';

Finally start a container with an interactive management client to verify that the cluster is up

    docker run -it --net=cluster mysql/mysql-cluster

Run the SHOW command to print cluster status. You should see the following

    Starting ndb_mgm
    -- NDB Cluster -- Management Client --
    ndb_mgm> show
    Connected to Management Server at: 192.168.0.2:1186
    Cluster Configuration
    ---------------------
    [ndbd(NDB)]	2 node(s)
    id=2	@192.168.0.3  (mysql-5.7.18 ndb-7.6.2, Nodegroup: 0, *)
    id=3	@192.168.0.4  (mysql-5.7.18 ndb-7.6.2, Nodegroup: 0)
    
    [ndb_mgmd(MGM)]	1 node(s)
    id=1	@192.168.0.2  (mysql-5.7.18 ndb-7.6.2)
    
    [mysqld(API)]	1 node(s)
    id=4	@192.168.0.10  (mysql-5.7.18 ndb-7.6.2)

## Customizing MySQL Cluster

The default MySQL Cluster image includes two config files which are also available in the github repository at https://github.com/mysql/mysql-docker/tree/mysql-cluster
* /etc/my.cnf
* /etc/mysql-cluster.cnf
To change the cluster, for instance by adding more nodes or change the network setup, these files must be updated. For more information on how to do so, please refer to the MySQL Cluster documentation at to https://dev.mysql.com/doc/index-cluster.html
To map up custom config files when starting the container, add the -v flag to load an external file. Example:
    docker run -d --net=cluster --name=management1 --ip=192.168.0.2 -v <path-to-your-file>/mysql-cluster.cnf:/etc/mysql-cluster.cnf mysql/mysql-cluster ndb_mgmd

# Supported Docker Versions

These images are officially supported by the MySQL team on Docker version 1.9. Support for older versions (down to 1.0) is provided on a best-effort basis, but we strongly recommend running on the most recent version, since that is assumed for parts of the documentation above.

# User Feedback

We welcome your feedback! For general comments or discussion, please drop us a line in the Comments section below. For bugs and issues, please submit a bug report at http://bugs.mysql.com under the category "MySQL Package Repos and Docker Images".
