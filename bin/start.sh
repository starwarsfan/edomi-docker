#!/usr/bin/env bash

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

	sed -i -e "s#^SSLCertificateFile.*$#SSLCertificateFile $CACRT#g" \
	       -e "s#^SSLCertificateKeyFile.*$#SSLCertificateKeyFile $CAKEY#g" ${SSLCONF}
fi

if [ -z "$HOSTIP" ]; then 
	echo "HOSTIP not set, using edomi default settings."
else
	echo "HOSTIP set to $HOSTIP ... configure $EDOMI_CONF and $HTTPD_CONF"
	sed -i -e "s#global_serverIP.*#global_serverIP='$HOSTIP'#" ${EDOMI_CONF}
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
	sed -i -e "s#global_knxGatewayActive=.*#global_knxGatewayActive='$KNXACTIVE'#" ${EDOMI_CONF}
fi

service mysqld start
service vsftpd start
service httpd start
service ntpd start
service sshd start
/usr/local/edomi/main/start.sh &

# Edomi start script is ended either by call of 'reboot' or 'shutdown'.
# These two files are replaced by helper scripts and their output is
# evaluated during the next steps.
#
# But at first wait until Edomi background script is exited.
wait

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
    echo "Exiting container with return value 1 to trigger Docker restart"
    exit 1
elif [ -e /tmp/doShutdown ] ; then
	# Edomi called 'shutdown'
    rm -f /tmp/do*
fi

# Exit container with 0, so Docker will not restart it
# Container must be startet with opeion "--restart=on-failure"
echo "Exiting container with return value 0 to prevent Docker restarting it"
exit 0
