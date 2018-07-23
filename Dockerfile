FROM debian:9

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
 && apt-get -y update \
 && apt-get -y install wget apt-transport-https gnupg

RUN wget -q -O- https://downloads.opennebula.org/repo/repo.key | apt-key add - \
 && echo "deb https://downloads.opennebula.org/repo/5.6/Debian/9 stable opennebula" > /etc/apt/sources.list.d/opennebula.list \
 && apt-get -y update \
 && ln -s /bin/true /usr/local/bin/systemctl \
 && apt-get -y install opennebula-node \
 && mkdir -p /var/run/sshd \
 && rm -f /etc/libvirt/qemu/networks/autostart/default.xml \
 && rm -f /usr/local/bin/systemctl

RUN echo "deb http://download.proxmox.com/debian stretch pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list \
 && wget http://download.proxmox.com/debian/proxmox-ve-release-5.x.gpg -O /etc/apt/trusted.gpg.d/proxmox-ve-release-5.x.gpg \
 && apt-get -y install debian-keyring debian-archive-keyring \
 && apt-get -y update \
 && apt-get -y install pve-qemu-kvm \
 && apt-get -y clean \
 && sed -i 's/use_lvmetad = 1/use_lvmetad = 0/g' /etc/lvm/lvm.conf
