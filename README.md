## Edomi-Docker

This is a Docker implementation for Edomi, a PHP-based smarthome framework.

For more information please refer to [Official website](http://www.edomi.de/) or [Support forum](https://knx-user-forum.de/forum/projektforen/edomi)


### 1. Build/Use the Edomi Container

You have two options:
- Pull the ready-made image from DockerHub or
- Build from scratch

The Edomi archive together with all required packages will be downloaded during docker build.
I've added openssh-server and additionally I've set the root password to '_123456_'.

#### 1.1 Image from Docker Hub

```shell
sudo docker pull starwarsfan/edomi-docker:amd64-latest
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
    -f amd64.Dockerfile \
    -t starwarsfan/edomi-baseimage:amd64-latest .
```

##### Build Edomi Docker image itself

If you built an own Edomi-Baseimage (the step before), you need to update it's reference
on the first line of the Dockerfile. The default first line looks like the following snippet,
where the version should be replaced with `latest`, if you build your personal base image
with `latest` as version:

```shell
FROM starwarsfan/edomi-baseimage:amd64-latest
```

Afterwards you can trigger the build with:

```shell
cd edomi-docker
sudo docker build \
    -f amd64.Dockerfile \
    -t starwarsfan/edomi-docker:amd64-latest .
```

You can pass a different root passwort to the build and you can pass the Edomi version to download too:

```shell
sudo docker build \
    -t starwarsfan/edomi-docker:amd64-latest \
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
    -e WEBSOCKETPORT=8080 \
    -e HOSTIP=192.168.178.3 \
    -d \
    starwarsfan/edomi-docker:amd64-latest
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
   The "WEBSOCKETPORT" variable will allow to set the websocket port in the edomi configuration.
   All three values (both sides of the mapping as well as the "WEBSOCKETPORT" value) must match.

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

The image offers three mountpoints:

* /var/edomi-backups
* /var/lib/mysql
* /usr/local/edomi

So it is possible to use dedicated volumes, which enables the possibility to reuse the volumes on a new container.

#### 3.1 Mount volume or folder for backups

With the additional run parameter _-v <host-folder>:<mountpoint>_ or _-v <volume>:<mountpoint>_ you can mount a
folder from the Docker host or a Docker volume into the container.

The usage of volumes should be preferred, as this offers the most flexibility. To do so, at first you should
create empty volumes:

```shell
sudo docker volume create edomi-backups
sudo docker volume create edomi-db
sudo docker volume create edomi-installation
```

Now the container can be started using these volumes:

```shell
sudo docker run \
    --name edomi \
    -v edomi-backups:/var/edomi-backups \
    -v edomi-db:/var/lib/mysql \
    -v edomi-installation:/usr/local/edomi \
    ...
```

If a new container is created using _empty_ volumes, then the content which is already existing on the used
location inside the used Docker image is copied onto the volume. So if you _docker run_ a new Edomi instance,
the whole content from these three mountpoint directories will be copied to the used volumes. So if the container
instance is destroyed and the volumes where used on a new Edomi instance, the content from the previous instance
will be there.

The usage of a directory from the Docker host instead of a volume is similar in it's usage. You need to use
the full path to the folder on the left side of the colon:

```shell
sudo docker run \
    --name edomi \
    -v /data/edomi-backups/:/var/edomi-backups/ \
    ...
```


#### 3.2 Mount dedicated files

With the additional run parameter _-v <host-folder>/<filename>:<container-folder>/<filename>_ you can
mount a file on the docker host into the Edomi container. This is useful if you use LBS like LBS19000690
(Jahrestage), which require access to separate files. So the run command may look like the following
example:

```shell
sudo docker run --name edomi -v /home/edomi/feiertage.csv:/usr/local/edomi/www/visu/feiertage.csv ...
```

#### 4 Migrate from Edomi 1.x (CentOS 6 Container) to 2.x with CentOS 7 Container

* Backup current Edomi instance using `Verwaltung > Datensicherung > Backup herunterladen`
* Create volumes to store data, see 3.1 above
* Start new container using created volumes
* Copy downloaded backup to created backup-volume
* Import backup using `Verwaltung > Datensicherung > Wiederherstellung`

### Appendix

#### A: Install docker

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

#### B: Useful commands

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

#### C: Update from 1.62 to 1.63

The following steps can be used if you're facing issues during the update from version 1.62 to 1.63.

To fix the update problems between these two versions, the image contains a fixed version of the file, which
causes the update failure. Here are the steps to do:

##### Fix using cmdline on Docker host

* Pause (not stop!) Edomi using the Admin-UI
* Execute the following cmd:
  ````
  $ docker exec -it <name-of-your-container> /root/patch_1.62.sh
  ````
* Update Edomi to 1.63 using the Admin-UI

##### Fix using cmdline inside the container

These variant could be used if you're running the Edomi container on a management tool like
[Portainer](https://www.portainer.io/). To do so, perform these steps:

* Pause (not stop!) Edomi using the Edomi Admin-UI
* Open the cmdline on the container
* Execute the following cmd:
  ````
  $ /root/patch_1.62.sh
  ````
* Update Edomi to 1.63 using the Admin-UI
