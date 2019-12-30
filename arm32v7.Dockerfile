FROM starwarsfan/edomi-baseimage:arm32v7-latest
MAINTAINER Yves Schumann <y.schumann@yetnet.ch>

# Define build arguments
ARG EDOMI_VERSION=EDOMI_200.tar
ARG ROOT_PASS=123456

# Define environment vars
ENV EDOMI_VERSION=${EDOMI_VERSION} \
    EDOMI_EXTRACT_PATH=/tmp/edomi/ \
    EDOMI_ARCHIVE=/tmp/edomi.tar \
    START_SCRIPT=/root/start.sh \
    ROOT_PASS=${ROOT_PASS} \
    EDOMI_BACKUP_DIR=/var/edomi-backups \
    EDOMI_DB_DIR=/var/lib/mysql \
    EDOMI_INSTALL_DIR=/usr/local/edomi

# Set root passwd and rename 'reboot' and 'shutdown' commands
RUN echo -e "${ROOT_PASS}\n${ROOT_PASS}" | (passwd --stdin root) \
 && mv /sbin/shutdown /sbin/shutdown_ \
 && mv /sbin/reboot /sbin/reboot_

ADD http://edomi.de/download/install/${EDOMI_VERSION} ${EDOMI_ARCHIVE}
RUN mkdir ${EDOMI_EXTRACT_PATH} \
 && tar -xf ${EDOMI_ARCHIVE} -C ${EDOMI_EXTRACT_PATH}

# Copy script into image
COPY bin/install.sh ${EDOMI_EXTRACT_PATH}
COPY bin/start.sh ${START_SCRIPT}
COPY sbin/reboot sbin/shutdown sbin/service /sbin/

# Make scripts executable
RUN chmod +x ${START_SCRIPT} /sbin/reboot /sbin/shutdown /sbin/service

# Install Edomi
RUN cd ${EDOMI_EXTRACT_PATH} \
 && ./install.sh

# Enable ssl for edomi and disable chmod for not existing /dev/vcsa
RUN sed -i -e "\$aLoadModule log_config_module modules/mod_log_config.so" \
           -e "\$aLoadModule setenvif_module modules/mod_setenvif.so" /etc/httpd/conf.d/ssl.conf \
 && sed -i "s/^\(.*vcsa\)/#\1/g" /usr/local/edomi/main/start.sh

# Mount points
VOLUME ${EDOMI_BACKUP_DIR} ${EDOMI_DB_DIR} ${EDOMI_INSTALL_DIR}

CMD ["/root/start.sh"]
