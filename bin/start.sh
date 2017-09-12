#!/usr/bin/env bash

# these are ENV VARs on docker run

HTTPD_CONF="/etc/httpd/conf/httpd.conf"
EDOMI_CONF="/usr/local/edomi/edomi.ini"
CSR="/etc/pki/tls/private/edomi.csr"
CAKEY="/etc/pki/tls/private/edomi.key"
CACRT="/etc/pki/tls/certs/edomi.crt"
SSLCONF="/etc/httpd/conf.d/ssl.conf"

if [ ! -f $CSR ] || [ ! -f $CAKEY ] || [ ! -f $CACRT ]; then
        openssl req -nodes -newkey rsa:2048 -keyout $CAKEY -out $CSR -subj "/C=NZ/ST=Metropolis/L=Metropolis/O=/OU=/CN=edomi"
	openssl x509 -req -days 3650 -in $CSR -signkey $CAKEY -out $CACRT

	sed -i -e "s#^SSLCertificateFile.*$#SSLCertificateFile $CACRT#g" $SSLCONF
	sed -i -e "s#^SSLCertificateKeyFile.*$#SSLCertificateKeyFile $CAKEY#g" $SSLCONF
fi

if [ -z "$HOSTIP" ]; then 
	echo "HOSTIP not set, using edomi default settings."
else
	echo "HOSTIP set to $HOSTIP ... configure $EDOMI_CONF and $HTTPD_CONF"
	sed -i -e "s#global_serverIP.*#global_serverIP='$HOSTIP'#" $EDOMI_CONF
	sed -i -e "s/^ServerName.*/ServerName $HOSTIP/g" $HTTPD_CONF
fi

if [ -z "$KNXGATEWAY" ]; then 
	echo "KNXGATEWAY not set, using edomi default settings."
else
	echo "KNXGATEWAY set to $KNXGATEWAY ... configure $EDOMI_CONF"
	sed -i -e "s#global_knxRouterIp=.*#global_knxRouterIp='$KNXGATEWAY'#" $EDOMI_CONF
fi

if [ -z "$KNXACTIVE" ]; then
	echo "KNXACTIVE not set, using edomi default settings."
else
	echo "KNXACTIVE set to $KNXACTIVE ... configure $EDOMI_CONF"
	sed -i -e "s#global_knxGatewayActive=.*#global_knxGatewayActive='$KNXACTIVE'#" $EDOMI_CONF
fi

set -x

pid=0

# SIGUSR1-handler
my_handler() {
  echo "my_handler"
}

# SIGTERM-handler
term_handler() {
  if [ $pid -ne 0 ]; then
    kill -SIGTERM "$pid"
    wait "$pid"
  fi
  exit 143; # 128 + 15 -- SIGTERM
}

# setup handlers
# on callback, kill the last background process, which is `tail -f /dev/null` and execute the specified handler
trap 'kill ${!}; my_handler' SIGUSR1
trap 'kill ${!}; term_handler' SIGTERM

service mysqld start
service vsftpd start
service httpd start
service ntpd start
service sshd start
/usr/local/edomi/main/start.sh &

pid="$!"

# wait forever
while true
do
  tail -f /dev/null & wait ${!}
done

