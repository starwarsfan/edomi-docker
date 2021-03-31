#!/usr/bin/env bash

# Setup ssh based on https://github.com/robertdebock/docker-centos-openssh/blob/master/start.sh
# Making all required files if they are not existing. (This means
# you may add a Docker volume on /etc/ssh or /root to insert your
# own files.
test -f /etc/ssh/ssh_host_ecdsa_key || /usr/bin/ssh-keygen -q -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -C '' -N ''
test -f /etc/ssh/ssh_host_rsa_key || /usr/bin/ssh-keygen -q -t rsa -f /etc/ssh/ssh_host_rsa_key -C '' -N ''
test -f /etc/ssh/ssh_host_ed25519_key || /usr/bin/ssh-keygen -q -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -C '' -N ''
test -f /root/.ssh/id_rsa || /usr/bin/ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ''
test -f /root/.ssh/id_rsa.pub || ssh-keygen -y -t rsa -f ~/.ssh/id_rsa > ~/.ssh/id_rsa.pub
test -f /root/.ssh/authorized_keys || /usr/bin/cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

# Change the owner.
chown -R root:root /root/.ssh

# Show the private key.
/usr/bin/cat /root/.ssh/id_rsa
/usr/bin/echo ""
/usr/bin/echo "Please save the printed private RSA key and login using:"
/usr/bin/echo "\"ssh -i \${savedkey} root@\${ipaddress}\""
/usr/bin/echo ""

### Dynamically set root password ############################################
if [[ -n "${ROOT_PASS}" ]] ; then
    echo -e "${ROOT_PASS}\n${ROOT_PASS}" | (passwd --stdin root)
fi

### Edomi ####################################################################
# These are ENV VARs on docker run

HTTPD_CONF="/etc/httpd/conf/httpd.conf"
EDOMI_CONF="/usr/local/edomi/edomi.ini"
CSR="/etc/pki/tls/private/edomi.csr"
CAKEY="/etc/pki/tls/private/edomi.key"
CACRT="/etc/pki/tls/certs/edomi.crt"
SSLCONF="/etc/httpd/conf.d/ssl.conf"

if [ ! -f ${CSR} ] || [ ! -f ${CAKEY} ] || [ ! -f ${CACRT} ]; then
    openssl req -nodes -newkey rsa:2048 -keyout ${CAKEY} -out ${CSR} -subj "/C=NZ/ST=Metropolis/L=Metropolis/O=/OU=/CN=edomi"
	openssl x509 -req -days 3650 -in ${CSR} -signkey ${CAKEY} -out ${CACRT}

	sed -i -e "s#^SSLCertificateFile.*\$#SSLCertificateFile $CACRT#g" \
	       -e "s#^SSLCertificateKeyFile.*\$#SSLCertificateKeyFile $CAKEY#g" ${SSLCONF}
fi

# Determine container IP on Docker network
CONTAINER_IP=$(hostname -i)

# Set edomi.ini config values based on environment vars given by docker.
if [ -z "$HOSTIP" ]; then
	echo "HOSTIP not set, using edomi default settings."
	sed -i -e "s#global_visuIP.*#global_visuIP='$CONTAINER_IP'#" ${EDOMI_CONF}
else
	echo "HOSTIP set to $HOSTIP ... configure $EDOMI_CONF and $HTTPD_CONF"
	sed -i -e "s#global_serverIP.*#global_serverIP='$HOSTIP'#" \
	       -e "s#global_knxIP.*#global_knxIP='$HOSTIP'#" \
	       -e "s#global_visuIP.*#global_visuIP='$CONTAINER_IP'#" ${EDOMI_CONF}
	sed -i -e "s/^ServerName.*/ServerName $HOSTIP/g" ${HTTPD_CONF}
fi

if [ -z "$KNXGATEWAY" ]; then
	echo "KNXGATEWAY not set, using edomi default settings."
else
	echo "KNXGATEWAY set to $KNXGATEWAY ... configure $EDOMI_CONF"
	sed -i -e "s#global_knxRouterIp=.*#global_knxRouterIp='$KNXGATEWAY'#" ${EDOMI_CONF}
fi

if [ -z "$KNXACTIVE" ]; then
	echo "KNXACTIVE not set, using edomi default settings."
else
	echo "KNXACTIVE set to $KNXACTIVE ... configure $EDOMI_CONF"
	sed -i -e "s#global_knxGatewayActive=.*#global_knxGatewayActive=$KNXACTIVE#" ${EDOMI_CONF}
fi

if [ -z "$WEBSOCKETPORT" ]; then
	echo "WEBSOCKETPORT not set, using edomi default settings."
else
	echo "WEBSOCKETPORT set to $WEBSOCKETPORT ... configure $EDOMI_CONF"
	sed -i -e "s#global_visuWebsocketPort=.*#global_visuWebsocketPort='$WEBSOCKETPORT'#" ${EDOMI_CONF}
fi

echo "Disabling heartbeat log output every second ... configure $EDOMI_CONF"
sed -i -e "s#global_serverConsoleInterval=.*#global_serverConsoleInterval=false#" ${EDOMI_CONF}

# set correct timezone based on edomi.ini
unlink /etc/localtime
edomiTZ=$(awk -F "=" '/^set_timezone/ {gsub(/[ \047]/, "", $2); print $2}' ${EDOMI_CONF})
ln -s /usr/share/zoneinfo/${edomiTZ} /etc/localtime

# Disable chmod for not existing /dev/vcsa
# Disable removal of mysql.sock
# Must be done on each start as start.sh might be replaced by an Edomi update!
sed -i -e "s@\(.*\)\(chmod 777 /dev/vcsa\)@#\2@g" \
       -e "s@\(.*\)\(service mysqld stop\)@#\2@g" \
       -e "s@\(.*\)\(rm -f \$MYSQL_PATH/mysql.sock\)@#\2@g" \
       -e "s@\(.*\)\(service mysqld start\)@#\2@g" /usr/local/edomi/main/start.sh

# Cleanup potential leftovers
rm -rf /run/httpd/*

systemctl start mysqld
systemctl start vsftpd
systemctl start httpd
systemctl start ntpd
systemctl start sshd

/usr/local/edomi/main/start.sh &

edomiPID=$!

# Edomi start script is ended either by call of 'reboot' or 'shutdown'.
# These two files are replaced by helper scripts and their output is
# evaluated during the next steps.

stop_services()
{
    systemctl stop sshd
    systemctl stop ntpd
    systemctl stop httpd
    systemctl stop vsftpd
    systemctl stop mysqld
}


docker_exit()
{
    echo "SIGINT or SIGTERM"
    php /usr/local/edomi/main/control.php quit
    echo "wait for edomi shutdown..."
    wait ${edomiPID}
    stop_services

    echo "shutdown now..."

    trap - SIGINT SIGTERM
    exit 0
}


trap docker_exit SIGINT SIGTERM

# But at first wait until Edomi background script is exited.
wait ${edomiPID}

# Handle if Edomi restore process is running, which will be sent to background
# by Edomi main script. So at this point the Edomi start script is finished but
# restore script might be running.
while true ; do
    sleep 5
    if $(ps aux | grep -v grep | grep "/tmp/edomirestore.sh" -q) ; then
		echo "Edomi restore is running..."
		continue
    elif $(ps aux | grep -v grep | grep "/tmp/edomiupdate.sh" -q) ; then
		echo "Edomi update is running..."
		continue
    else
		break
    fi
done

if [ -e /tmp/doReboot ] ; then
	# Edomi called 'reboot'
    rm -f /tmp/do*
    # Trigger container restart by simulating an internal error
    # Container must be startet with opeion "--restart=on-failure"

    stop_services

    echo "Exiting container with return value 1 to trigger Docker restart"
    exit 1

elif [ -e /tmp/doShutdown ] ; then
	# Edomi called 'shutdown'
    rm -f /tmp/do*
fi

# Exit container with 0, so Docker will not restart it
# Container must be startet with opeion "--restart=on-failure"

stop_services

echo "Exiting container with return value 0 to prevent Docker restarting it"
exit 0
