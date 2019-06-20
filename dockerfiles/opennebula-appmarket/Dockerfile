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
ARG VERSION=2.1.0
RUN wget https://github.com/OpenNebula/addon-appmarket/releases/download/release-${VERSION}/appmarket_${VERSION}.deb \
 && dpkg -i appmarket_${VERSION}.deb \
 && rm -f appmarket_${VERSION}.deb \
 && cd /usr/lib/one/ruby/oneapps/market \
 && bundle install

# Logging to /dev/stdout
RUN sed -i 's|^\(APPMARKET_LOG *=\).*|\1 "/dev/stdout"|' /usr/lib/one/ruby/oneapps/market/controllers/appmarket-server.rb

# https://github.com/OpenNebula/addon-appmarket/pull/57
RUN sed -i "/require 'appmarket_version'/i require 'one_helper'" /usr/lib/one/ruby/oneapps/market/appmarket_client.rb

USER oneadmin
ENTRYPOINT [ "/usr/bin/ruby", "/usr/lib/one/ruby/oneapps/market/controllers/appmarket-server.rb" ]
