# MySQL


### 关于容器和宿主机文件文件夹同步的调查

### 案例compose

```yml
# add this file
# default MySQL root password is 123456

version: '3.1'

services:

  mysql:
    image: mysql:5.7
    container_name: mysql_5.7
    restart: always
    ports:
     - 3305:3306
    volumes:
     - ./mysql_config/conf.d:/etc/mysql/conf.d
     - ./mysql_data:/var/lib/mysql
     - ./docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d
    environment:
      MYSQL_ROOT_PASSWORD: 123456
```



### 结果

<img width="884" alt="数据卷同步规则" src="https://user-images.githubusercontent.com/45913187/113966242-4dd53480-9861-11eb-9382-ea223d4c494a.png">

### 案例compose

```yml
# add this file
# default MySQL root password is 123456

version: '3.1'

services:

  mysql:
    image: mysql:5.7
    container_name: mysql_5.7
    restart: always
    ports:
     - 3305:3306
    volumes:
     - ./mysql_config/conf.d:/etc/mysql/conf.d
     - ./mysql_data:/var/lib/mysql
     - ./docker-entrypoint-initdb.d:/docker-entrypoint-initdb.d
    environment:
      MYSQL_ROOT_PASSWORD: 123456
```

### 概念理解

- 宿主机目录对应的物理储存地址被**容器**和宿主机操作系统同时管理。

- 宿主机目录可以看成一个硬盘被挂载在容器目录下
- 宿主机的目录和容器的目录可以看成两个指针指向同一个物理地址
- 非空容器目录为什么不行？数据卷的意义在于数据持久化，将应用数据分离，因此数据在宿主机，若容器目录非空，会造成逻辑冲突，也就是怎样去同步宿主机目录和容器目录，解决两边文件的差异。因此只能挂载在容器中的空目录下。



### tips

- 若挂载的是目录，容器目录要为空目录
- 若容器目录不存在，也可以挂载会自动创建

- volumes基本规则->**文件夹:文件夹；文件:文件


### 概念理解

- 宿主机目录对应的物理储存地址被**容器**和宿主机操作系统同时管理。

- 宿主机目录可以看成一个硬盘被挂载在容器目录下
- 宿主机的目录和容器的目录可以看成两个指针指向同一个物理地址
- 非空容器目录为什么不行？数据卷的意义在于数据持久化，将应用数据分离，因此数据在宿主机，若容器目录非空，会造成逻辑冲突，也就是怎样去同步宿主机目录和容器目录，解决两边文件的差异。因此只能挂载在容器中的空目录下。



### tips

- 若挂载的是目录，容器目录要为空目录
- 若容器目录不存在，也可以挂载会自动创建

- volumes基本规则->**文件夹:文件夹；文件:文件
