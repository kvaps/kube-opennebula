FROM centos:7

RUN echo -e '[opennebula]\nname=opennebula\nbaseurl=https://downloads.opennebula.org/repo/5.4/CentOS/7/x86_64\nenabled=1\ngpgkey=https://downloads.opennebula.org/repo/repo.key\ngpgcheck=1\n#repo_gpgcheck=1' > /etc/yum.repos.d/opennebula.repo \
 && yum -y install opennebula-node-kvm
