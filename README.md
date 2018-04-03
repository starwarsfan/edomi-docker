## Edomi-Docker (Release 1.58)
 
 This is a docker implementation for Edomi, a PHP-based smarthome framework.
 It is based on the initial work of [pfischi](https://github.com/pfischi/edomi-docker), thx a lot!

 For more information please refer to [Official website](http://www.edomi.de/) or [Support forum](https://knx-user-forum.de/forum/projektforen/edomi)


### 1. Build/Use the Edomi Container

You have two options: 
- Pull the ready-made image from DockerHub or 
- Build from scratch

The Edomi archive together with all required packages will be downloaded during docker build. 
I've added openssh-server and additionally I've set the root password to '_123456_'.

#### 1.1 Image from Docker Hub

```shell
sudo docker pull starwarsfan/edomi-docker
```

#### 1.2 Build from scratch

The image build is split into two separate build steps. The first step generates updated CentOS 
base image with all required packages. The second step build the Edomi image, which is based on
the image from the first build step.

##### Pull Edomi-Docker Git repos from GitHub

```shell
sudo git clone https://github.com/starwarsfan/edomi-baseimage.git
sudo git clone https://github.com/starwarsfan/edomi-docker.git
```

##### Build Edomi baseimage

```shell
cd edomi-baseimage
sudo docker build \
    -t starwarsfan/edomi-baseimage:6.8.1 .
```

##### Build Edomi Docker image itself

```shell
cd edomi-docker
sudo docker build \
    -t starwarsfan/edomi-docker:latest .
```

You can pass a different root passwort to the build and you can pass the Edomi version to download too:

```shell
sudo docker build \
    -t starwarsfan/edomi-docker:latest \
    --build-arg ROOT_PASS=Th3Passw0rd \
    --build-arg EDOMI_VERSION=EDOMI-Beta_156.zip .
```


### 2. Starting docker container

```shell
sudo docker run \
    --name edomi \
    --restart=on-failure \
    -p 80:80 \
    -p 8080:8080 \
    -p 3671:3671/udp \
    -p 50000:50000/udp \
    -p 50001:50001/udp \
    -p 22222:22 \
    -e KNXGATEWAY=192.168.178.4 \
    -e KNXACTIVE=true \
    -e HOSTIP=192.168.178.3 \
    -d \
    starwarsfan/edomi-docker:latest
```

With this configuration the edomi web instance is reachable via URL _http://\<docker-host-ip\>/admin_ or 
_https://\<docker-host-ip\>/admin_ and the commandline via ssh with _ssh -p 22222 \<docker-host-ip\>_.
With the (optional) parameters KNXGATEWAY, KNXACTIVE and HOSTIP you can pre-configure some settings for Edomi. 
Leave it empty to do this via the Edomi admin webpage. Keep in mind to set "global_serverIP" in Edomi (or via 
docker run parameter 'HOSTIP') to your Docker host IP. Otherwise the KNX communication probably will not work.
Change http and/or https port to your needs.

If you use other Edomi modules which communicate using dedicated ports, you need to map them using additional 
_-p <host-port>:<container-port>_ parameters.

#### 2.1 Explanation of parameters

**It is important to map all used ports!** According to the example with the default values above, here's a short 
description:
 * -p 80:80
   
   Mapping of used http port to Edomi http port. 
 
 * -p 8080:8080
 
   Mapping of Websocket port. These values must be the same on both sides of the colon and correspond to the 
   configuration value on Edomi base configuration.
   
 * -p 3671:3671/udp
 
   Mapping of used port for KNX traffic. As this is UDP traffic, it must be finished with "/udp" right after 
   the internal port, which must correspond to the configuration value on Edomi base configuration.
   
 * -p 50000:50000/udp
 
   Mapping of used port for KNX control endpoint. As this is UDP traffic, it must be finished with "/udp" 
   right after the internal port, which must correspond to the configuration value on Edomi base configuration.
   
 * -p 50001:50001/udp
 
   Mapping of used port for KNX data endpoint. As this is UDP traffic, it must be finished with "/udp" 
   right after the internal port, which must correspond to the configuration value on Edomi base configuration.
   
 * -p 22222:22
 
   Mapping of used ssh port to access the container using ssh.
   

**Please note:**

It is important to use the option _--restart=on-failure_ because it is used to handle Edomi shutdown or restart
from the admin ui. The trick is to exit the container with a non zero exit code in case Edomi should be restartet.
If it should be shut down, the exit code will be zero, which is not a failure for Docker and so the container
will not be restartet again.

### 3. Mount external content
 
#### 3.1 Mount volume or folder for backups

With the additional run parameter _-v <host-folder>:/var/edomi-backups/_ you can mount a folder on the docker 
host which contains the Edomi backups outside of the container. So the run command may look like the following 
example:

```shell
sudo docker run --name edomi -v /data/edomi-backups/:/var/edomi-backups/ ...
```


#### 3.2 Mount dedicated files

With the additional run parameter _-v <host-folder>/<filename>:<container-folder>/<filename>_ you can 
mount a file on the docker host into the Edomi container. This is useful if you use LBS like LBS19000690 
(Jahrestage), which require access to separate files. So the run command may look like the following 
example:

```shell
sudo docker run --name edomi -v /home/edomi/feiertage.csv:/usr/local/edomi/www/visu/feiertage.csv ...
```

### Appendix

#### A Install docker

 This instruction works for a <b>Centos7</b> docker host. Other distributions may need some adjustments.

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

#### B Useful commands

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
