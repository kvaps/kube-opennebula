FROM ubuntu:20.04 as builder

# Setup environment variables
ENV VERSION=5.12.0.4 \
    PACKAGES_VERSION=5.12.6 \
    PKG_VERSION=1 \
    CONTACT="Unsupported Community Build" \
    GIT_VERSION="not known" \
    DISTRO=ubuntu2004 \
    DEBIAN_FRONTEND=noninteractive

# Install build dependencies (https://docs.opennebula.io/5.12/integration/references/build_deps.html)
RUN apt-get update \
 && apt-get install -y \
      ubuntu-dev-tools \
      bash-completion \
      bison \
      debhelper \
      default-jdk \
      flex \
      javahelper \
      libmysql++-dev \
      libsqlite3-dev \
      libssl-dev \
      libsystemd-dev \
      libws-commons-util-java \
      libxml2-dev \
      libxslt1-dev \
      libcurl4-openssl-dev \
      libcurl4 \
      libvncserver-dev \
      postgresql-server-dev-all \
      python3-setuptools \
      ruby \
      scons \
      npm \
      ronn \
      rename \
      jq

# Download sources
RUN wget -q -O - https://github.com/OpenNebula/one/archive/release-$VERSION.tar.gz | tar xzf - \
 && mv /one-release-$VERSION /opennebula-$VERSION \
 && wget -q -O - https://github.com/kvaps/packages/archive/release-$PACKAGES_VERSION.tar.gz | tar xzf - \
 && mv /packages-release-$PACKAGES_VERSION /packages-$VERSION

WORKDIR /opennebula-$VERSION

# Apply patches
RUN wget -q -O - https://github.com/OpenNebula/one/pull/4585.diff | patch -p1

# Build docs
RUN cd share/man \
 && ./build.sh

# Build Sunstone
RUN cd src/sunstone/public \
 && ./build.sh -d \
 && export PATH=$PATH:$PWD/node_modules/.bin \
 && ./build.sh \
 && rm -rf node_modules/

# Build Java OCA
#RUN cd src/oca/java \
# && ./build.sh -d

# Prepare sources
RUN tar -czf /opennebula_$VERSION.orig.tar.gz . \
 && cp -r /packages-$VERSION/templates/$DISTRO/ debian \
 && wget -q https://downloads.opennebula.io/extra/xmlrpc-c.tar.gz \
 && wget -q https://downloads.opennebula.io/packages/opennebula-$VERSION/java-oca-$VERSION.tar.gz \
 && sed -i '/new_xmlrpc=yes/a\    context=yes \\' /packages-$VERSION/sources/build_opennebula.sh \
 && tar -czf build_opennebula.tar.gz -C /packages-$VERSION/sources build_opennebula.sh xml_parse_huge.patch

# Download Ruby gems
RUN bash -x /packages-$VERSION/rubygems/download.sh /opennebula_$VERSION.orig.tar.gz Ubuntu2004 opennebula-rubygems-$VERSION.tar

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
RUN apt-get install -y $(dpkg-checkbuilddeps 2>&1 | sed -e 's/.*Unmet build dependencies: //' -e 's/[\(][^)]*[\)]//g')

# Build binary package
RUN dpkg-buildpackage -us -uc

# Preserve only packages
FROM ubuntu:20.04
COPY --from=builder /*.tar.xz /*.deb /packages/
