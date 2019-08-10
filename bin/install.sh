#!/usr/bin/env bash

# EDOMI install path (DO NOT CHANGE!)
MAIN_PATH="/usr/local/edomi"

configureEnvironment () {
    mkdir -p /etc/selinux/targeted/contexts/
    echo '<busconfig><selinux></selinux></busconfig>' > /etc/selinux/targeted/contexts/dbus_contexts

	# -------------------------------
	echo -e "\033[32m>>> FTP konfigurieren\033[39m"
	rm -f /etc/vsftpd/ftpusers
	rm -f /etc/vsftpd/user_list
	sed -i -e '/listen=/ s/=.*/=YES/' /etc/vsftpd/vsftpd.conf
	sed -i -e '/listen_ipv6=/ s/=.*/=NO/' /etc/vsftpd/vsftpd.conf
	sed -i -e '/userlist_enable=/ s/=.*/=NO/' /etc/vsftpd/vsftpd.conf

	# -------------------------------
	echo -e "\033[32m>>> Apache konfigurieren\033[39m"
	sed -i -e "s/#ServerName www\.example\.com/ServerName $SERVERIP/" /etc/httpd/conf/httpd.conf
	sed -i -e "s#DocumentRoot \"/var/www/html\"#DocumentRoot \"$MAIN_PATH/www\"#" /etc/httpd/conf/httpd.conf
	sed -i -e "s#<Directory \"/var/www\">#<Directory \"$MAIN_PATH/www\">#" /etc/httpd/conf/httpd.conf
	sed -i -e "s#<Directory \"/var/www/html\">#<Directory \"$MAIN_PATH/www\">#" /etc/httpd/conf/httpd.conf

	# -------------------------------
	echo -e "\033[32m>>> mySQL/MariaDB konfigurieren\033[39m"
	systemctl start mariadb
	/usr/bin/mysqladmin -u root password ""
	mysql -e "DROP DATABASE test;"
	mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
	mysql -e "FLUSH PRIVILEGES;"
	mysql -e "GRANT ALL ON *.* TO mysql@'%';"

	echo "key_buffer_size=256M" 			> /tmp/tmp.txt
	echo "sort_buffer_size=8M" 				>> /tmp/tmp.txt
	echo "read_buffer_size=16M" 			>> /tmp/tmp.txt
	echo "read_rnd_buffer_size=4M" 			>> /tmp/tmp.txt
	echo "myisam_sort_buffer_size=4M" 		>> /tmp/tmp.txt
	echo "join_buffer_size=4M" 				>> /tmp/tmp.txt
	echo "query_cache_limit=8M" 			>> /tmp/tmp.txt
	echo "query_cache_size=8M" 				>> /tmp/tmp.txt
	echo "query_cache_type=1" 				>> /tmp/tmp.txt
	echo "wait_timeout=28800" 				>> /tmp/tmp.txt
	echo "interactive_timeout=28800" 		>> /tmp/tmp.txt
	sed -i '/\[mysqld\]/r /tmp/tmp.txt' /etc/my.cnf

	# mySQL-Symlink erstellen
	echo "Alias=mysqld.service" 			> /tmp/tmp.txt
	sed -i '/\[Install\]/r /tmp/tmp.txt' /usr/lib/systemd/system/mariadb.service
	ln -s '/usr/lib/systemd/system/mariadb.service' '/etc/systemd/system/mysqld.service'
	systemctl daemon-reload

	# -------------------------------
	echo -e "\033[32m>>> PHP konfigurieren\033[39m"
	sed -i -e '/short_open_tag =/ s/=.*/= On/' /etc/php.ini
	sed -i -e '/post_max_size =/ s/=.*/= 100M/' /etc/php.ini
	sed -i -e '/upload_max_filesize =/ s/=.*/= 100M/' /etc/php.ini
	sed -i -e '/max_file_uploads =/ s/=.*/= 1000/' /etc/php.ini
}

install_edomi () {
	echo -e "\033[32m>>> EDOMI installieren\033[39m"
	systemctl stop mariadb
	sleep 1

	if [ -f "EDOMI/EDOMI-Backup.edomibackup" ] ; then
		tar -xf EDOMI/EDOMI-Backup.edomibackup -C /
		chmod 777 -R ${MAIN_PATH}
	else
		mkdir -p ${MAIN_PATH}
		tar -xvf edomi.edomiinstall -C ${MAIN_PATH}
		chmod 777 -R ${MAIN_PATH}
	fi

	sed -i \
	    -e "s/service\(.*\)start/systemctl start\1/g" \
	    -e "s/service\(.*\)stop/systemctl stop\1/g" \
	    /usr/local/edomi/main/start.sh
}

show_title () {
	echo -e "\033[42m\033[30m                                                                                \033[49m\033[39m"
	echo -e "\033[42m\033[30m                       EDOMI - (c) Dr. Christian Gärtner                        \033[49m\033[39m"
	echo -e "\033[42m\033[30m                                                                                \033[49m\033[39m"
}

show_splash () {
	show_title
	echo -e "\033[32mDie EDOMI-Installation ist abgeschlossen.\033[39m"
	echo -e "\033[32mBeim nächsten Systemstart wird EDOMI automatisch gestartet.\033[39m"
	echo -e "\033[32mNeustart mit: reboot (ENTER)\033[39m"
	echo ""
}

# Installationsscript

osversion="$(cat /etc/issue)"
clear
show_title

configureEnvironment
install_edomi
show_splash
exit
