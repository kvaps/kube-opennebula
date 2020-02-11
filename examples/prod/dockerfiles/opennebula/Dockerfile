FROM docker.io/kvaps/opennebula:v5.10.1

ARG VERSION

USER root

RUN apt-get -y update \
 && apt-get -y install vim gnupg2 \
 && apt-get -y clean

# Add aditional configs
ADD vmm_exec/* /etc/one/vmm_exec/
ADD vmm/kvm/kvmrc /var/lib/one/remotes/etc/vmm/kvm/kvmrc

# Install linstor-client
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys CC1B5A793C04BB3905AD837734893610CEAA9512 \
 && echo "deb http://ppa.launchpad.net/linbit/linbit-drbd9-stack/ubuntu bionic main" \
      > /etc/apt/sources.list.d/linbit.list  \
 && apt-get -y update \
 && apt-get -y install linstor-client jq \
 && apt-get -y clean

USER oneadmin

RUN curl -L https://github.com/kvaps/opennebula-static-marketplace/archive/master.tar.gz | tar xzf - -C /tmp \
 && mv /tmp/opennebula-static-marketplace-master/driver/static /var/lib/one/remotes/market/static \
 && rm -rf /tmp/opennebula-static-marketplace-master

ARG LINSTOR_UN_TAG=v1.2.7
RUN curl -L https://github.com/OpenNebula/addon-linstor_un/archive/${LINSTOR_UN_TAG}.tar.gz | tar -xzvf - -C /tmp \
 && mv /tmp/addon-linstor_un-${LINSTOR_UN_TAG#v*}/vmm/kvm/* /var/lib/one/remotes/vmm/kvm/ \
 && mkdir -p /var/lib/one/remotes/etc/datastore/linstor_un \
 && mv /tmp/addon-linstor_un-${LINSTOR_UN_TAG#v*}/datastore/linstor_un/linstor_un.conf /var/lib/one/remotes/etc/datastore/linstor_un/linstor_un.conf \
 && mv /tmp/addon-linstor_un-${LINSTOR_UN_TAG#v*}/datastore/linstor_un /var/lib/one/remotes/datastore/linstor_un \
 && mv /tmp/addon-linstor_un-${LINSTOR_UN_TAG#v*}/tm/linstor_un /var/lib/one/remotes/tm/linstor_un \
 && rm -rf /tmp/addon-linstor_un-${LINSTOR_UN_TAG#v*}
