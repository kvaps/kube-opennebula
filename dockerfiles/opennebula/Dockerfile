FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install opennebula-common and rubygems
COPY --from=ghcr.io/kvaps/opennebula-packages:v5.12.0.4-1 /packages/opennebula-common_*.deb /packages/ruby-opennebula_*_all.deb /packages/opennebula-tools_*.deb /packages/opennebula-rubygems_*.deb /packages/opennebula-common-onescape_*.deb /packages/
RUN apt-get update \
 && ln -s /bin/true /usr/bin/systemd-tmpfiles \
 && apt-get -y install /packages/*.deb \
 && mkdir -p /var/log/one /var/lock/one /var/run/one \
 && apt-get -y clean \
 && rm -rf /var/lib/apt/lists/ \
 && chown oneadmin: /var/log/one /var/lock/one /var/run/one

# Logging to stdout
RUN for i in oned.log sched.log onehem.log sunstone.log novnc.log onegate.log oneflow.log; do ln -sf "/proc/1/fd/1" "/var/log/one/$i"; done

# Install opennebula
COPY --from=ghcr.io/kvaps/opennebula-packages:v5.12.0.4-1 /packages/opennebula_*.deb /packages/
RUN apt-get -y update \
 && apt-get -y install mysql-client \
 && apt-get -y install /packages/opennebula_*.deb \
 && rm -f /usr/bin/systemd-tmpfiles \
 && apt-get -y clean \
 && rm -rf /var/lib/apt/lists/

# Add missing migration packages
RUN VERSION=5.12.0.4 \
 && wget -q -O - https://github.com/OpenNebula/one/archive/release-$VERSION.tar.gz | \
   tar -xzf - -C /usr/lib/one/ruby/onedb \
   --strip-components 3 \
   one-release-$VERSION/src/onedb/local \
   one-release-$VERSION/src/onedb/shared

# Fix permissions and cleanup
RUN chown -R oneadmin:oneadmin /etc/one \
 && rm -f /var/lib/one/.one/one_auth \
      /var/lib/one/.ssh/authorized_keys \
      /var/lib/one/.ssh/id_rsa \
      /var/lib/one/.ssh/id_rsa.pub

USER oneadmin
ENTRYPOINT [ "/usr/bin/oned", "-f" ]
#ENTRYPOINT [ "/usr/bin/mm_sched" ]
#ENTRYPOINT [ "/usr/lib/one/onehem/onehem-server.rb" ]
