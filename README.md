## edomi-docker (Edomi release: v1.48)
 
 This is a docker implementation for Edomi, a PHP-based smarthome framework.
 It is based on the initial work of [pfischi](https://github.com/pfischi/edomi-docker), thx a lot!
 For more information please refer to:
 
 [Official website](http://www.edomi.de/)
 [Support forum](https://knx-user-forum.de/forum/projektforen/edomi)

 This instruction works for a <b>Centos7</b> docker host. Other distributions need some adjustments.


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

You now have two options: build from scratch or pull the ready-made image from DockerHub. 
The Edomi archive together with all required packages will be downloaded during docker build. 
I've added openssh-server and additionally I've set the root password to '123456'.

#### 2a Image from Docker Hub

```shell
sudo docker pull pfischi/edomi
```

#### 2b Build from scratch

##### Pull edomi-docker from github

```shell
sudo git clone https://github.com/starwarsfan/edomi-docker.git
cd edomi-docker
```

##### Pull Centos 6.8 docker image and build Edomi container

```shell
sudo docker pull centos:6.8
sudo docker build -t starwarsfan/edomi:latest .
```

You can pass a different root passwort to the build and you can pass the Edomi version to download too:

```shell
sudo docker build -t starwarsfan/edomi:latest --build-arg ROOT_PASS=Th3Passw0rd --build-arg EDOMI_VERSION=EDOMI-Beta_152.zip .
```


### 3. Starting docker container

```shell
sudo docker run --name edomi -p 42900:80 -p 42901:443 -p 22222:22 -p 50000:50000/udp -p 50001:50001/udp -e KNXGATEWAY=192.168.178.4 -e KNXACTIVE=true -e HOSTIP=192.168.178.3 -d pfischi/edomi:latest
```

With this configuration the edomi web instance is reachable via URL _http://<docker-host-ip>:42900/admin_ or 
_https://<docker-host-ip>:42901/admin_ and the commandline via ssh with _ssh -p 22222 <docker-host-ip>_.
With the (optional) parameters KNXGATEWAY, KNXACTIVE and HOSTIP you can pre-configure some settings for Edomi. 
Leave it empty to do this via the Edomi admin webpage. Keep in mind to set "global_serverIP" in Edomi (or via 
docker run script 'HOSTIP') to your Docker host IP. Otherwise the KNX communication probably will not work.
Change http and/or https port to your needs.

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

check running / stopped container

```shell
sudo docker ps -a
```

stop the container

```shell
sudo docker stop edomi
```

start the container

```shell
sudo docker start edomi
```

get logs from container

```shell
sudo docker logs -f edomi
```
