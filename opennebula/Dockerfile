FROM ubuntu:18.04

# Configure dpkg
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
 && apt-get -y update \
 && apt-get -y install wget apt-transport-https gnupg \
 && apt-get -y clean

# Install opennebula-node
RUN wget -q -O- https://downloads.opennebula.org/repo/repo.key | apt-key add - \
 && echo "deb https://downloads.opennebula.org/repo/5.6/Ubuntu/18.04 stable opennebula" > /etc/apt/sources.list.d/opennebula.list \
 && apt-get -y update \
 && apt-get -y install opennebula \
 && apt-get -y clean \
 && sed -i 's/apt-get install/apt-get -y install/g' /usr/share/one/install_gems \
 && echo '0\n' | /usr/share/one/install_gems \
 && mkdir /var/lock/one && chown oneadmin: /var/lock/one \
 && sed -i 's/\(SYSTEM *= *\)"file"/\1"std"/' /etc/one/oned.conf

USER oneadmin
ENTRYPOINT [ "/usr/bin/oned", "-f" ]
