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

# Install opennebula-exporter dependencies
RUN apt-get update \
 && apt-get -y install xmlstarlet \
 && apt-get -y clean \
 && rm -rf /var/lib/apt/lists/

COPY --from=prom/node-exporter:v0.18.1 /bin/node_exporter /bin/node_exporter
ADD https://raw.githubusercontent.com/kvaps/opennebula-exporter/7b4c10ec07377d1b4b9094020c856b0b6c0b5c73/opennebula_exporter /usr/bin/opennebula_exporter
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
