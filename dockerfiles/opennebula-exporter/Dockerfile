# ------------------------------------------------------------------------------
# Common part
# ------------------------------------------------------------------------------

# === Stage 1 ===

FROM ubuntu:18.04 as builder

# Setup environment variables
ENV VERSION=5.10.3 \
    PKG_VERSION=1 \
    CONTACT="Unsupported Community Build" \
    GIT_VERSION="not known" \
    DISTRO=ubuntu1804

# Install build dependencies
RUN apt-get update \
 && apt-get install -y debhelper ubuntu-dev-tools bash-completion \
      bison default-jdk flex javahelper libxmlrpc3-client-java \
      libxmlrpc3-common-java libxml2-dev ruby scons dh-systemd \
      npm ruby-ronn rename

# Download sources
RUN wget -q -O - https://github.com/OpenNebula/one/archive/release-$VERSION.tar.gz | tar xzf - \
 && mv /one-release-$VERSION /opennebula-$VERSION \
 && wget -q -O - https://github.com/OpenNebula/packages/archive/release-$VERSION.tar.gz | tar xzf - \
 && mv /packages-release-$VERSION /packages-$VERSION

WORKDIR /opennebula-$VERSION

# Apply patches
RUN wget -q -O - https://github.com/OpenNebula/one/pull/3569.diff | patch -p1 \
 && wget -q -O - https://github.com/OpenNebula/one/pull/4324.diff | patch -p1

# Build docs
RUN cd share/man \
 && ./build.sh

# Build Sunstone
RUN cd src/sunstone/public \
 && ./build.sh -d \
 && export PATH=$PATH:$PWD/node_modules/.bin \
 && ./build.sh \
 && rm -rf node_modules/

# Prepare sources
RUN tar -czf /opennebula_$VERSION.orig.tar.gz . \
 && cp -r /packages-$VERSION/templates/$DISTRO/ debian \
 && wget -q http://downloads.opennebula.org/extra/xmlrpc-c.tar.gz \
 && tar -czf build_opennebula.tar.gz -C /packages-$VERSION/sources build_opennebula.sh xml_parse_huge.patch

# Build Ruby gems
RUN "/packages-$VERSION/rubygems/build.sh" \
    "/opennebula_$VERSION.orig.tar.gz" \
    "/" \
    "$(echo ${DISTRO} | sed 's/\b./\u\0/g')" \
    "${VERSION}-${PKG_VERSION}" \
    "${CONTACT}"

# Generate requirements for all Ruby gem packages and process control template
RUN for F in /opennebula-rubygem-*.deb; do \
        _NAME=$(dpkg-deb -f "${F}" Package); \
        _VERS=$(dpkg-deb -f "${F}" Version); \
        RUBYGEMS_REQ="${RUBYGEMS_REQ}${_NAME} (= ${_VERS}), "; \
    done \
 && m4 -D_VERSION_="${VERSION}" \
    -D_PKG_VERSION_="${PKG_VERSION}" \
    -D_CONTACT_="${CONTACT}" \
    -D_DATE_="${DATE}" \
    -D_RUBYGEMS_REQ_="${RUBYGEMS_REQ}" \
    -D_WITH_RUBYGEMS_ \
    debian/control.m4 > debian/control

# Generate changelog
RUN printf '%s\n\n' \
  "opennebula (${VERSION}-${PKG_VERSION}) unstable; urgency=low" \
  "  * Build for ${VERSION}-${PKG_VERSION} (Git revision ${GIT_VERSION})" \
  " -- ${CONTACT}  $(date -R)" \
  > debian/changelog

# Generate gitversion
RUN echo "${GIT_VERSION}" > debian/gitversion
  
# Build source package
RUN dpkg-source --include-binaries -b .

# Install dependencies
RUN apt-get install -y $(dpkg-checkbuilddeps 2>&1 | sed 's/.*Unmet build dependencies: //')

# Build binary package
RUN dpkg-buildpackage -us -uc

# === Stage 2 ===

FROM ubuntu:18.04

# Install opennebula-common and rubygems
COPY --from=builder /opennebula-common_*.deb /ruby-opennebula_*_all.deb /opennebula-tools_*.deb /opennebula-rubygem*.deb /packages/
RUN apt-get update \
 && apt-get -y install /packages/*.deb \
 && mkdir -p /var/log/one /var/lock/one \
 && apt-get -y clean \
 && chown oneadmin: /var/log/one /var/lock/one

# ------------------------------------------------------------------------------
# Specific part
# ------------------------------------------------------------------------------

RUN apt-get update \
 && apt-get -y install xmlstarlet \
 && apt-get -y clean

COPY --from=prom/node-exporter:v0.18.1 /bin/node_exporter /bin/node_exporter
ADD https://raw.githubusercontent.com/kvaps/opennebula-exporter/7b4c10ec07377d1b4b9094020c856b0b6c0b5c73/opennebula_exporter /bin/opennebula_exporter
RUN chmod 755 /bin/opennebula_exporter \
 && mkdir -p /metrics \
 && chown oneadmin:oneadmin /metrics

ENTRYPOINT [ \
  "/bin/node_exporter", \
  "--no-collector.arp", \
  "--no-collector.bcache", \
  "--no-collector.bonding", \
  "--no-collector.conntrack", \
  "--no-collector.cpu", \
  "--no-collector.cpufreq", \
  "--no-collector.diskstats", \
  "--no-collector.edac", \
  "--no-collector.entropy", \
  "--no-collector.filefd", \
  "--no-collector.filesystem", \
  "--no-collector.hwmon", \
  "--no-collector.infiniband", \
  "--no-collector.ipvs", \
  "--no-collector.loadavg", \
  "--no-collector.mdadm", \
  "--no-collector.meminfo", \
  "--no-collector.netclass", \
  "--no-collector.netdev", \
  "--no-collector.netstat", \
  "--no-collector.nfs", \
  "--no-collector.nfsd", \
  "--no-collector.pressure", \
  "--no-collector.sockstat", \
  "--no-collector.stat", \
  "--no-collector.time", \
  "--no-collector.timex", \
  "--no-collector.uname", \
  "--no-collector.vmstat", \
  "--no-collector.xfs", \
  "--no-collector.zfs", \
  "--collector.textfile.directory=/metrics" \
]
