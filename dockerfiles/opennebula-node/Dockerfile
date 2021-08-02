FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install opennebula-node
COPY --from=ghcr.io/kvaps/opennebula-packages:v5.12.0.4-1 /packages/opennebula-common_*.deb /packages/opennebula-common-onescape_*.deb /packages/opennebula-node_*.deb /packages/
RUN apt-get -y update \
 && ln -s /bin/true /usr/local/bin/systemctl \
 && apt-get -y install /packages/*.deb \
 && rm -f /usr/local/bin/systemctl \
 && rm -f /etc/libvirt/qemu/networks/autostart/default.xml \
 && apt-get -y clean \
 && rm -rf /var/lib/apt/lists/
