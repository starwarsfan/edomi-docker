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
git clone https://github.com/starwarsfan/edomi-baseimage.git
git clone https://github.com/starwarsfan/edomi-docker.git
```

##### Build Edomi baseimage

```shell
cd edomi-baseimage
sudo docker build \
    -f amd64.Dockerfile \
    -t starwarsfan/edomi-baseimage:amd64-latest .
```

##### Build Edomi Docker image

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
    -p 80:88 \
    -p 50000:50000/udp \
    -p 50001:50001/udp \
    -p 22222:22 \
    -e KNXACTIVE=true \
    -e KNXGATEWAYIP=192.168.178.4 \
    -e KNXGATEWAYPORT=3700 \
    -e HOSTIP=192.168.178.3 \
    -d \
    starwarsfan/edomi-docker:amd64-latest
```

With this configuration the edomi web instance is reachable via URL _http://\<docker-host-ip\>/admin_ or
_https://\<docker-host-ip\>/admin_ and the commandline via ssh with _ssh -p 22222 \<docker-host-ip\>_.
With the (optional) parameters KNXGATEWAYIP, KNXGATEWAYPORT, KNXACTIVE and HOSTIP you can pre-configure some 
settings for Edomi.
Leave it empty to do this via the Edomi admin webpage. Keep in mind to set "global_serverIP" in Edomi (or via
docker run parameter 'HOSTIP') to your Docker host IP. Otherwise the KNX communication probably will not work.
Change http and/or https port to your needs.

If you use other Edomi modules which communicate using dedicated ports, you need to map them using additional
_-p <host-port>:<container-port>_ parameters.

#### 2.1 Portmappings

**It is important to map all used ports!** According to the example with the default values above, here's a short
description:

**Mandatory:**
 * -p <host-port>:88

   Mapping of used http port to internal Edomi http port. This port is used to access the admin ui 
   (`http://<host-ip>:<host-port>/admin/`) and the visualization (`http://<host-ip>:<host-port>/visu/`)
   
   **Important:** If a different source port than 80 is used, HTTPPORT must be set with the used port too!

**Optional:**
 * -p 50000:50000/udp

   If using KNX, the mapping of used port for KNX control endpoint. As this is UDP traffic, it must be finished 
   with "/udp" right after the internal port, which must correspond to the configuration value on Edomi base 
   configuration.

 * -p 50001:50001/udp

   If using KNX, the mapping of used port for KNX data endpoint. As this is UDP traffic, it must be finished with "/udp"
   right after the internal port, which must correspond to the configuration value on Edomi base configuration.

 * -p 22222:22

   Mapping of used ssh port to access the container using ssh. If not mapping some external port to port 22,
   ssh can't be used to access the container.

#### 2.2 Environment variables
**Mandatory:**
 * -e HOSTIP=192.168.178.3

   IP of the host on which the container is running

**Optional:**
 * -e ROOT_PASS=sup3rS3cr3tPassw0rd

   The password to access the container using ssh. You should set this var with a password of your choice
  as the default root password is 123456. If the container is initially starting, a ssh keypair will be
  created and the private key is printed to stdout. So have a look at the container log to get the private
  key for ssh access.
  
   It doesn't matter if you're _not_ mapping some external port to the ssh port (22) inside of the container 
  as in this case the container can't be accessed using ssh.

 * -e HTTPPORT=80

   If a different http source port than 80 is mapped, this variable must be set with the used port!

 * -e KNXACTIVE=true
   
   Used to activate Edomi's KNX module

 * -e KNXGATEWAYIP=192.168.178.4 
   
   IP address of the used KNX gateway

 * -e KNXGATEWAYPORT=3700 
   
   Port to access KNX on the gateway

 * -e TZ=Europe/Zurich 
   
   Timezone to use on Edomi configuration

#### 2.3 Restart behaviour
**Important!**

It is important to use the option `--restart=on-failure` because it is used to handle Edomi shutdown or restart
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

With the additional run parameter `-v <host-folder>:<mountpoint>` or `-v <volume>:<mountpoint>` you can mount a
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
the whole content from these three mountpoint directories will be copied to the used volumes. If the container
instance is destroyed and the volumes where re-used on a new Edomi instance, the content from the previous instance
will be there.

The usage of a directory from the Docker host instead of a volume is similar in it's usage. You need to use
the full path to the folder on the left side of the colon:

```shell
sudo docker run \
    --name edomi \
    -v /data/edomi-backups/:/var/edomi-backups/ \
    ...
```

**Important:** The copy-step of the container content into an empty volume is not working with bind mounts! So The usage of bind mounts from the host into the container makes sense only for the backups.


#### 3.2 Mount dedicated files

With the additional run parameter `-v <host-folder>/<filename>:<container-folder>/<filename>` you can
mount a file on the docker host into the Edomi container. This is useful if you use LBS like LBS19000690
(Jahrestage), which require access to separate files. So the run command may look like the following
example:

```shell
sudo docker run \
    --name edomi \
    -v /home/edomi/feiertage.csv:/usr/local/edomi/www/visu/feiertage.csv \
    ...
```

#### 4 Reverse proxy in front of Edomi container
If you use an Nginx reverse proxy in front of the Edomi container, you need to 
add the following location entry:
```
map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}

server {
    ...
    location /edomi {
        sub_filter          "WebSocket(serverProtocol+'://'+serverIp+':88/websocket')" "WebSocket(serverProtocol+'://'+serverIp+'/edomi/websocket')";
        sub_filter_types    application/javascript;
        sub_filter_once     off;

        proxy_pass          http://192.168.123.123:88/;
        proxy_set_header    X-Forwarded-Host $host;
        proxy_set_header    X-Forwarded-Server $host;
        proxy_set_header    X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header    X-Real-IP $remote_addr;
        proxy_redirect>     off;
        proxy_http_version  1.1;
        proxy_set_header    Upgrade $http_upgrade;
        proxy_set_header    Connection "upgrade";
    }
```
To make this work you need to replace:
- `edomi` (2 times) with your used path from the URL to Edomi
- `88` (also 2 times) with the used source port, which you map onto the container
- `192.168.123.123` with the IP of the machine, where the Edomi container is running

**Important:** Make sure to replace only `edomi` and `88` with your used values, 
don't touch the slashes a/o colon right before or after the replacements!

#### 5 Migrate from Edomi 1.x (CentOS 6 Container) to 2.x with Rocky Linux Container

* Update Edomi to the latest version
* Backup current Edomi instance using `Verwaltung > Datensicherung > Backup herunterladen`
* Create volumes to store data, see 3.1 above
* Start new container using created volumes
* Copy downloaded backup to created backup-volume
* Import backup using `Verwaltung > Datensicherung > Wiederherstellung`

### Appendix

#### A: Install docker

See https://docs.docker.com/engine/install/

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
