FROM debian:9

# Configure dpkg
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
 && apt-get -y update \
 && apt-get -y install wget apt-transport-https gnupg \
 && apt-get -y clean

# Install opennebula-node
RUN wget -q -O- https://downloads.opennebula.org/repo/repo.key | apt-key add - \
 && echo "deb https://downloads.opennebula.org/repo/5.6/Debian/9 stable opennebula" > /etc/apt/sources.list.d/opennebula.list \
 && apt-get -y update \
 && ln -s /bin/true /usr/local/bin/systemctl \
 && apt-get -y install opennebula-node \
 && mkdir -p /var/run/sshd \
 && rm -f /etc/libvirt/qemu/networks/autostart/default.xml \
 && rm -f /usr/local/bin/systemctl \
 && apt-get -y clean \
 && sed -i 's/use_lvmetad = 1/use_lvmetad = 0/g' /etc/lvm/lvm.conf \
 && sed -i 's/^#uri_default/uri_default/' /etc/libvirt/libvirt.conf \
 && sed -i 's/^#\(unix_sock\|auth_unix\)/\1/' /etc/libvirt/libvirtd.conf \
 && echo 'export LIBVIRT_DEFAULT_URI="qemu:///system"' > /var/lib/one/.bash_profile
