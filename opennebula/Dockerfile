FROM ubuntu:18.04
ARG VERSION=5.8.2

# Configure dpkg
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
 && apt-get -y update \
 && apt-get -y install wget apt-transport-https gnupg \
 && apt-get -y clean

# Install opennebula-gems
RUN wget -q -O- https://downloads.opennebula.org/repo/repo.key | apt-key add - \
 && echo "deb https://downloads.opennebula.org/repo/5.8/Ubuntu/18.04 stable opennebula" > /etc/apt/sources.list.d/opennebula.list \
 && apt-get -y update \
 && apt-get -y install opennebula-tools \
 && apt-get -y clean \
 && sed -i 's/apt-get install/apt-get -y install/g' /usr/share/one/install_gems \
 && echo '0\n' | /usr/share/one/install_gems \
 && mkdir -p /var/log/one /var/lock/one \
 && chown oneadmin: /var/log/one /var/lock/one

# Install opennebula
RUN apt-get -y update \
 && apt-get -y install opennebula mysql-client less \
 && apt-get -y clean

# Logging to /dev/stdout
RUN sed -i 's/\(SYSTEM *= *\)"file"/\1"std"/' /etc/one/oned.conf \
 && sed -i 's/\(system *= *\)"file"/\1"std"/' /etc/one/sched.conf

# Fix: https://github.com/OpenNebula/one/issues/3074
RUN sed -i '/scp -rp/ s|/. |/* |' /usr/lib/one/ruby/CommandManager.rb /usr/lib/one/ruby/cli/one_helper/onehost_helper.rb

USER oneadmin
ENTRYPOINT [ "/usr/bin/oned", "-f" ]
#ENTRYPOINT [ "/usr/bin/mm_sched" ]
