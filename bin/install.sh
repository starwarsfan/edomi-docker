# EDOMI-Hauptpfad (NICHT ÄNDERN!)
MAIN_PATH="/usr/local/edomi"

install_timezone () {
	# Zeitzone zur Sicherheit auf GMT einstellen
	rm -f /etc/localtime
	ln -s /usr/share/zoneinfo/GMT0 /etc/localtime
}

install_config () {

	# Firewall
	cp config/config /etc/selinux/
	
	# Apache
	cp config/welcome.conf /etc/httpd/conf.d/
	cp config/httpd.conf /etc/httpd/conf/
	sed -i -e "s#===INSTALL-HTTP-ROOT===#$MAIN_PATH/www#g" /etc/httpd/conf/httpd.conf

	# PHP
	cp config/php.conf /etc/httpd/conf.d/
	cp config/php.ini /etc/
	
	# mySQL
	cp config/my.cnf /etc/
	
	# FTP
	cp config/vsftpd.conf /etc/vsftpd/
	rm -f /etc/vsftpd/ftpusers
	rm -f /etc/vsftpd/user_list
}

install_mysql () {
	service mysqld start
	/usr/bin/mysqladmin -u root password ""
	mysql -e "DROP DATABASE test;"
	mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
	mysql -e "FLUSH PRIVILEGES;"
	
	# Remote-Access aktivieren (z.B. vom iMac aus)
	# mysql -e "GRANT ALL ON *.* TO mysql@'%';"
}

install_edomi () {
	service mysqld stop
	sleep 1

	if [ -f "EDOMI/EDOMI-Backup.edomibackup" ]
	then
		tar -xf EDOMI/EDOMI-Backup.edomibackup -C /
		chmod 777 -R $MAIN_PATH		
	else
		mkdir -p $MAIN_PATH
		tar -xf EDOMI/EDOMI-Public.edomiinstall -C $MAIN_PATH --strip-components=3
		chmod 777 -R $MAIN_PATH
	fi
}


install_extensions () {
	cp php/bcompiler.so /usr/lib64/php/modules/bcompiler.so
	cp php/bcompiler.ini /etc/php.d/bcompiler.ini
}

show_splash () {
	echo -e "\033[32m"
	echo "--------------------------------------------------------------------------------"
	echo "                                                                                "
	echo "        OOOOOOOOOOO  OOOOOOOO        OOOOOOOOO        OOOOOOOOOOOOOO  O         "
	echo "        O            O       OO    OO         OO    OO     O       O  O         "
	echo "        O            O         O  O             O  O       O       O  O         "
	echo "        OOOOOOOO     O         O  O             O  O       O       O  O         "
	echo "        O            O         O  O             O  O       O       O  O         "
	echo "        O            O       OO    OO         OO   O       O       O  O         "
	echo "        OOOOOOOOOOO  OOOOOOOO        OOOOOOOOO     O       O       O  O         "
	echo "                                                                                "
	echo "        EDOMI-Installation abgeschlossen      (c) Dr. Christian Gärtner         "
	echo "                                                                                "
	echo "--------------------------------------------------------------------------------"
	echo -e "\033[39m"
}

# Installationsscript

osversion="$(cat /etc/issue)"
clear
echo "================================================================================"
echo "                                                                                "
echo "                       EDOMI - (c) Dr. Christian Gärtner                        "
echo "                                                                                "
echo "================================================================================"
echo ""

install_config
install_mysql
install_edomi
install_extensions
show_splash
exit
