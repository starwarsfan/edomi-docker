FROM starwarsfan/edomi-baseimage:6.8.1
MAINTAINER Yves Schumann <y.schumann@yetnet.ch>

# Define build arguments
ARG EDOMI_VERSION=EDOMI-Beta_153.zip
ARG ROOT_PASS=123456

# Define environment vars
ENV EDOMI_VERSION=${EDOMI_VERSION} \
    EDOMI_ZIP=/tmp/edomi.zip \
    EDOMI_INSTALL_PATH=/tmp/edomi/Install/ \
    START_SCRIPT=/root/start.sh \
    ROOT_PASS=${ROOT_PASS} \
    EDOMI_BACKUP_DIR=/var/edomi-backups

# Mount point for Edomi backups
VOLUME ${EDOMI_BACKUP_DIR}

# Set root passwd and rename 'reboot' and 'shutdown' commands
RUN echo -e "${ROOT_PASS}\n${ROOT_PASS}" | (passwd --stdin root) \
 && mv /sbin/shutdown /sbin/shutdown_ \
 && mv /sbin/reboot /sbin/reboot_

# Copy entrypoint script
COPY bin/start.sh ${START_SCRIPT}

# Copy reboot and shutdown helper scripts
COPY sbin/reboot sbin/shutdown /sbin/

# Make scripts executable
RUN chmod +x ${START_SCRIPT} /sbin/reboot /sbin/shutdown

ADD http://edomi.de/download/install/${EDOMI_VERSION} ${EDOMI_ZIP}
RUN unzip -q ${EDOMI_ZIP} -d /tmp/

# Copy install script and entrypoint script
COPY bin/install.sh ${EDOMI_INSTALL_PATH}
RUN cd ${EDOMI_INSTALL_PATH} \
 && ./install.sh

# Enable ssl for edomi
RUN sed -i -e "\$aLoadModule log_config_module modules/mod_log_config.so" \
           -e "\$aLoadModule setenvif_module modules/mod_setenvif.so" /etc/httpd/conf.d/ssl.conf

# Update to handle websocket. Can be removed later if already implemented that way,
# see https://knx-user-forum.de/forum/projektforen/edomi/900020-edomi-releases-updates-aktuell-version-1-52?p=1126332#post1126332
RUN sed -i "s/visu_socket.open.*$/visu_socket.open(window.location.host,<?echo global_visuWebsocketPort;?>);/g" /usr/local/edomi/www/visu/apps/app0.php

CMD ["/root/start.sh"]
