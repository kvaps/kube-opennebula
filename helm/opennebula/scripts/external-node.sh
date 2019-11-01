#/bin/sh
host_exec() {
  nsenter --target 1 --mount --uts --ipc --net --pid -- "$@" ;
}
host_copy() {
  tar -C "$1" -chf- "$3" | host_exec tar -C "$2" -xf-
}

echo "Connfiguring oneadmin account"
if ! $(host_exec getent passwd oneadmin >/dev/null); then
  host_exec useradd -u 9869 -U -s /bin/bash -m -d /var/lib/one -G disk,kvm oneadmin
fi
host_exec rm -rf /var/lib/one/.ssh
host_copy /var/lib/one /var/lib/one .ssh
host_exec chown 9869:9869 -R /var/lib/one/.ssh
host_exec chmod 700 /var/lib/one/.ssh
host_exec chmod 600 /var/lib/one/.ssh/id_rsa
host_copy /config /etc/sudoers.d opennebula.sudoers
host_exec mv -f /etc/sudoers.d/opennebula.sudoers /etc/sudoers.d/opennebula

echo "Connecting NFS shares:"
while read share mountpoint fstype options; do
  echo -n "  $share - "
  host_exec mountpoint -q "$mountpoint" && echo ok && continue
  host_exec mkdir -p "$mountpoint"
  if host_exec mount -t "$fstype" -o "$options" "$share" "$mountpoint"; then
    echo "ok (new)"
  else
    echo fail
    FAILED=1
  fi
  host_exec chown 9869:9869 "$mountpoint"
done < /config/mounts

echo "Run additional connfiguration"
#
# Do some configuration here: eg. connect storages, configre networking
#

# Sleep forever
exec tail -f /dev/null
