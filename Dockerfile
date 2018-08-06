FROM ubuntu:16.04

# Configure dpkg
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
 && apt-get -y update \
 && apt-get -y install wget apt-transport-https gnupg xz-utils sudo \
 && apt-get -y clean

# Latest libvirt
RUN LIBVIRT_VERSION=4.6.0 \
 && wget -O- https://libvirt.org/sources/libvirt-${LIBVIRT_VERSION}.tar.xz | tar xJf - \
 && cd libvirt-${LIBVIRT_VERSION} \
 && echo "deb-src http://archive.ubuntu.com/ubuntu xenial-updates main restricted universe multiverse" \
      > /etc/apt/sources.list.d/xenial-udates-src.list \
 && apt-get -y update \
 && apt-get -y build-dep libvirt \
 && ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var --with-esx=no \
 && make \
 && make install \
 && ldconfig \
 && sudo groupadd libvirt \
 && systemctl enable libvirtd.service \
 && cd / \
 && rm -rf \
      libvirt-${LIBVIRT_VERSION} \
      /etc/apt/sources.list.d/xenial-udates-src.list

# Install opennebula-node
RUN wget -q -O- https://downloads.opennebula.org/repo/repo.key | apt-key add - \
 && echo "deb https://downloads.opennebula.org/repo/5.6/Ubuntu/16.04 stable opennebula" > /etc/apt/sources.list.d/opennebula.list \
 && apt-get -y update \
 && ln -s /bin/true /usr/local/bin/systemctl \
 && apt-get -y install opennebula-node \
 && mkdir -p /var/run/sshd \
 && rm -f /etc/libvirt/qemu/networks/autostart/default.xml \
 && rm -f /usr/local/bin/systemctl \
 && apt-get -y clean
