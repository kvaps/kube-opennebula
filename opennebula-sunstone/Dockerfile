FROM ubuntu:18.04

# Configure dpkg
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
 && apt-get -y update \
 && apt-get -y install wget apt-transport-https gnupg \
 && apt-get -y clean

# Install opennebula-gems
RUN wget -q -O- https://downloads.opennebula.org/repo/repo.key | apt-key add - \
 && echo "deb https://downloads.opennebula.org/repo/5.6/Ubuntu/18.04 stable opennebula" > /etc/apt/sources.list.d/opennebula.list \
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

# Install undaemonize
ADD undaemonize.c /undaemonize.c
RUN gcc /undaemonize.c -o /usr/local/bin/undaemonize

USER oneadmin
ENTRYPOINT [ "/bin/sh", "-c", "ln -sf /dev/stdout /var/log/one/sunstone.log && exec /usr/bin/ruby /usr/lib/one/sunstone/sunstone-server.rb" ]
#ENTRYPOINT [ "/bin/sh", "-c", "ln -sf /dev/stdout /var/log/one/novnc.log && undaemonize novnc-server start" ]
