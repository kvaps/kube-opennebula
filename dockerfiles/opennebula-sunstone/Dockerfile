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

# Install opennebula-sunstone
RUN apt-get -y update \
 && ln -s /bin/true /usr/local/bin/systemd-tmpfiles \
 && apt-get -y install opennebula-sunstone \
 && rm -f /usr/local/bin/systemd-tmpfiles \
 && apt-get -y clean

# Logging to /dev/stdout, do not daemonize novnc-server
RUN sed -i 's|^\(SUNSTONE_LOG *=\).*|\1 "/dev/stdout"|' /usr/lib/one/sunstone/sunstone-server.rb \
 && sed -i 's|^\(VNC_LOG *=\).*|\1 "/dev/stdout"|' /usr/bin/novnc-server \
 && sed -i '/cmd *=/a\        exec(cmd)' /usr/lib/one/ruby/OpenNebulaVNC.rb

USER oneadmin
ENTRYPOINT [ "/usr/bin/ruby", "/usr/lib/one/sunstone/sunstone-server.rb" ]
#ENTRYPOINT [ "/usr/bin/ruby", "/usr/bin/novnc-server", "start" ]
