FROM centos:6.8

ARG EDOMI_VERSION=EDOMI-Beta_152.zip
ARG ROOT_PASS=123456

ENV EDOMI_TMP_PATH=/tmp \
	EDOMI_VERSION=${EDOMI_VERSION} \
    EDOMI_ZIP=$EDOMI_TMP_PATH/edomi.zip \
    EDOMI_INSTALL_PATH=$EDOMI_TMP_PATH/edomi/Install/ \
    START_SCRIPT=/root/start.sh \
    ROOT_PASS=${ROOT_PASS}

RUN yum update -y \
 && yum upgrade -y \
 && yum -y install \
	nano \
	wget \
	unzip \
	php-devel \
	mysql \
	mysql-server \
	vsftpd \
	httpd \
	tar \
	php-gd \
	php-mysql \
	php-pear \
	php-soap \
	ntp \
	openssh-server \
	mod_ssl

ADD http://edomi.de/download/install/${EDOMI_VERSION} ${EDOMI_ZIP}
RUN unzip -q ${EDOMI_ZIP} -d ${EDOMI_TMP_PATH}
COPY bin/install.sh ${EDOMI_INSTALL_PATH}
RUN cd ${EDOMI_INSTALL_PATH} && ./install.sh

# set root passwd
RUN echo -e "${ROOT_PASS}\n${ROOT_PASS}" | (passwd --stdin root)

# enable ssl for edomi
RUN sed -i -e "\$aLoadModule log_config_module modules/mod_log_config.so" /etc/httpd/conf.d/ssl.conf
RUN sed -i -e "\$aLoadModule setenvif_module modules/mod_setenvif.so" /etc/httpd/conf.d/ssl.conf

# copy entrypoint script
COPY bin/start.sh ${START_SCRIPT}
RUN chmod +x ${START_SCRIPT}
CMD ["/root/start.sh"]
