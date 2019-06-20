FROM ubuntu:18.04
ARG VERSION=5.8.2

# Configure dpkg
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
 && apt-get -y update \
 && apt-get -y install wget apt-transport-https gnupg \
 && apt-get -y clean

# Install opennebula-gems
RUN wget -q -O- https://downloads.opennebula.org/repo/repo.key | apt-key add - \
 && echo "deb https://downloads.opennebula.org/repo/5.8/Ubuntu/18.04 stable opennebula" > /etc/apt/sources.list.d/opennebula.list \
 && apt-get -y update \
 && apt-get -y install opennebula-tools \
 && apt-get -y clean \
 && sed -i 's/apt-get install/apt-get -y install/g' /usr/share/one/install_gems \
 && echo '0\n' | /usr/share/one/install_gems \
 && mkdir -p /var/log/one /var/lock/one \
 && chown oneadmin: /var/log/one /var/lock/one

# Install opennebula-gate
RUN apt-get -y update \
 && apt-get -y install opennebula-gate \
 && apt-get -y clean

# Logging to /dev/stdout
RUN sed -i 's|^\(ONEGATE_LOG *=\).*|\1 "/dev/stdout"|' /usr/lib/one/onegate/onegate-server.rb

USER oneadmin
ENTRYPOINT [ "/usr/bin/ruby", "/usr/lib/one/onegate/onegate-server.rb" ]
