FROM debian:9

# Configure dpkg
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
 && apt-get -y update \
 && apt-get -y install wget apt-transport-https gnupg \
 && apt-get -y clean

# Install latest qemu (from pve-repo)
RUN echo "deb http://download.proxmox.com/debian stretch pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list \
 && wget http://download.proxmox.com/debian/proxmox-ve-release-5.x.gpg -O /etc/apt/trusted.gpg.d/proxmox-ve-release-5.x.gpg \
 && apt-get -y install debian-keyring debian-archive-keyring \
 && apt-get -y update \
 && apt-get -y install pve-qemu-kvm \
 && apt-get -y clean

# Install latest libvirt
RUN echo 'deb http://deb.debian.org/debian unstable main' >> /etc/apt/sources.list \
 && echo 'Package: *\nPin: release a=unstable\nPin-Priority: 100' >> /etc/apt/preferences \
 && apt-get -y update \
 && apt-get -y -t unstable install libvirt-daemon-system libvirt-clients \
 && apt-get -y clean \
 && sed -i 's/^#\(unix_sock\|auth_unix\)/\1/' /etc/libvirt/libvirtd.conf

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
 && sed -i 's/^#uri_default/uri_default/' /etc/libvirt/libvirt.conf

