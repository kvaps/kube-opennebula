FROM ubuntu:18.04
ARG VERSION=5.8.2

# Configure dpkg
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
 && apt-get -y update \
 && apt-get -y install wget apt-transport-https gnupg \
 && apt-get -y clean

# Backport qemu-kvm from xenial (https://bugs.launchpad.net/ubuntu/+source/libvirt/+bug/1710960)
RUN echo "deb http://archive.ubuntu.com/ubuntu/ xenial main\ndeb http://archive.ubuntu.com/ubuntu/ xenial-updates main" >> /etc/apt/sources.list \
 && apt-get -y update \
 && apt-get -y install qemu-utils/xenial-updates qemu-block-extra/xenial-updates qemu-kvm/xenial-updates qemu-system-x86/xenial-updates qemu-system-common/xenial-updates ipxe-qemu/xenial-updates acl libacl1 \
 && apt-get -y clean \
 && apt-mark hold qemu-utils qemu-block-extra qemu-kvm qemu-system-x86 qemu-system-common ipxe-qemu

# Install opennebula-node
RUN wget -q -O- https://downloads.opennebula.org/repo/repo.key | apt-key add - \
 && echo "deb https://downloads.opennebula.org/repo/5.8/Ubuntu/18.04 stable opennebula" > /etc/apt/sources.list.d/opennebula.list \
 && apt-get -y update \
 && ln -s /bin/true /usr/local/bin/systemctl \
 && apt-get -y install opennebula-node \
 && mkdir -p /var/run/sshd \
 && rm -f /etc/libvirt/qemu/networks/autostart/default.xml \
 && rm -f /usr/local/bin/systemctl \
 && apt-get -y clean
