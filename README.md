## edomi-docker (Edomi release 1.52)
 
 This is a docker implementation for Edomi, a PHP-based smarthome framework.
 It is based on the initial work of [pfischi](https://github.com/pfischi/edomi-docker), thx a lot!

 For more information please refer to:
 
 [Official website](http://www.edomi.de/) or [Support forum](https://knx-user-forum.de/forum/projektforen/edomi)

 This instruction works for a <b>Centos7</b> docker host. Other distributions may need some adjustments.


### 1. Install docker

```shell
sudo tee /etc/yum.repos.d/docker.repo <<-'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/7/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF
```

```shell
sudo yum install docker-engine -y
```
```shell
sudo systemctl enable docker.service
```
```shell
sudo systemctl start docker.service
```

### 2. Build the Edomi Container

You now have two options: 
- Build from scratch or 
- Pull the ready-made image from DockerHub. 

The Edomi archive together with all required packages will be downloaded during docker build. 
I've added openssh-server and additionally I've set the root password to '123456'.

#### 2a Image from Docker Hub

```shell
sudo docker pull starwarsfan/edomi
```

#### 2b Build from scratch

The image build is split into two separate build steps. The first step generates updated CentOS 
base image with all required packages. The second step build the Edomi image, which is based on
the image from the first build step.

##### Pull edomi-docker repo from github

```shell
sudo git clone https://github.com/starwarsfan/edomi-docker.git
cd edomi-docker
```

##### Pull Centos 6.8 docker image, build base and Edomi image

```shell
sudo docker pull centos:6.8
cd edomi-baseimage
sudo docker build -t starwarsfan/edomi-baseimage:6.8.0 .
cd ..
sudo docker build -t starwarsfan/edomi:latest .
```

You can pass a different root passwort to the build and you can pass the Edomi version to download too:

```shell
sudo docker build -t starwarsfan/edomi:latest --build-arg ROOT_PASS=Th3Passw0rd --build-arg EDOMI_VERSION=EDOMI-Beta_152.zip .
```


### 3. Starting docker container

```shell
sudo docker run --name edomi --net=host --restart=on-failure -p 22222:22 -e KNXGATEWAY=192.168.178.4 -e KNXACTIVE=true -e HOSTIP=192.168.178.3 -d starwarsfan/edomi:latest
```

With this configuration the edomi web instance is reachable via URL _http://<docker-host-ip>/admin_ or 
_https://<docker-host-ip>/admin_ and the commandline via ssh with _ssh -p 22222 <docker-host-ip>_.
With the (optional) parameters KNXGATEWAY, KNXACTIVE and HOSTIP you can pre-configure some settings for Edomi. 
Leave it empty to do this via the Edomi admin webpage. Keep in mind to set "global_serverIP" in Edomi (or via 
docker run script 'HOSTIP') to your Docker host IP. Otherwise the KNX communication probably will not work.
Change http and/or https port to your needs.

**Note 1:**
It is important to use the option _--net=host_, otherwise the websocket connection for the visu will not work.
At the moment this may be a drawback, if you need http- a/o https-ports on your Docker host for something else
than Edomi.

**Note 2:**
It is important to use the option _--restart=on-failure_ because it is used to handle Edomi shutdown or restart
from the admin ui. The trick is to exit the container with a non zero exit code in case Edomi should be restartet.
If it should be shut down, the exit code will be zero, which is not a failure for Docker and so the container
will not be restartet again.

#### 3.a Mount volume or folder for backups

With the additional run parameter _-v <host-folder>:/var/edomi-backups/_ you can mount a folder on the docker 
host which contains the Edomi backups outside of the container. So the run command may look like the following example:

```shell
sudo docker run --name edomi -v /data/edomi-backups/:/var/edomi-backups/ ...
```


### 4. Autostart Edomi Docker container

```shell
sudo cp docker-edomi.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start docker-edomi.service
sudo systemctl enable docker-edomi.service
```

### 5. Useful commands

Check running / stopped container:

```shell
sudo docker ps -a
```

Stop the container

```shell
sudo docker stop edomi
```

Start the container

```shell
sudo docker start edomi
```

Get logs from container

```shell
sudo docker logs -f edomi
```

Open cmdline inside of container

```shell
sudo docker exec -i -t edomi /bin/bash
```
