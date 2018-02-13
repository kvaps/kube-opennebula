FROM ubuntu:16.04

RUN sed -i 's|# \(deb-src http://archive.ubuntu.com/ubuntu/ xenial main restricted\)|\1|' /etc/apt/sources.list \
 && rm -rf /var/lib/update-notifier/package-data-downloads/partial/* \
 && apt-get -y update \
 && apt-get -y install checkinstall \
 && apt-get -y build-dep libvirt \
 && apt-get -y source libvirt \
 && cd libvirt-* \
 && ./configure --prefix=/usr --localstatedir=/var --sysconfdir=/etc --without-systemd-daemon --without-apparmor --without-apparmor-mount --without-pm-utils --without-udev --without-dbus --without-firewalld --without-audit --without-avahi \
 && make \
 && checkinstall -y --install=no \
 && apt-get -y autoremove $(apt-cache showsrc libvirt | sed -e '/Build-Depends/!d;s/Build-Depends: \|,\|([^)]*),*\|\[[^]]*\]//g') \
 && dpkg -i libvirt_*_amd64.deb \
 && cd - \
 && rm -rf libvirt-* \
 && groupadd libvirt \
 && useradd -d /var/lib/libvirt -g libvirt -s /bin/false libvirt

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
 && apt-get -y update \
 && apt-get -y install wget apt-transport-https \
 && wget -q -O- https://downloads.opennebula.org/repo/repo.key | apt-key add - \
 && echo "deb https://downloads.opennebula.org/repo/5.4/Ubuntu/16.04 stable opennebula" > /etc/apt/sources.list.d/opennebula.list

RUN apt-get -y update \
 && apt-get -y install opennebula-node || true

RUN mkdir -p /var/run/sshd

