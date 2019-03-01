# kube-opennebula

## Quick start

#### Deploy Control plane

Create namespace

```bash
kubectl create namespace opennebula
```

Generate keys

```bash
mkdir opennebula-ssh-keys
ssh-keygen -f opennebula-ssh-keys/id_rsa -C oneadmin -P ''
cat opennebula-ssh-keys/id_rsa.pub > opennebula-ssh-keys/authorized_keys

cat > opennebula-ssh-keys/config <<EOT
Host *
    StrictHostKeyChecking no
    Port 2222
    UserKnownHostsFile /dev/null
    GSSAPIAuthentication no
    User oneadmin
EOT

kubectl create secret generic -n opennebula opennebula-ssh-keys --from-file=opennebula-ssh-keys
```

Generate oneadmin key

```bash
mkdir opennebula-one-keys
echo oneadmin:BHMOmCj85umdeqT4Fr0JnkDEmU7zbk > opennebula-one-keys/one_auth
kubectl create secret generic -n opennebula opennebula-one-keys --from-file=opennebula-one-keys
```

Create main opennebula daemon and take other keys

```bash
kubectl create -n opennebula-test -f examples/control-plane/oned-config.yaml
kubectl create -n opennebula-test -f examples/control-plane/oned.yaml

kubectl exec -n opennebula-test opennebula-oned-0 -- tar -C /var/lib/one/.one/ -cvf - . | tar -C ./opennebula-one-keys -xf -
kubectl delete secret -n opennebula opennebula-one-keys
kubectl create secret generic -n opennebula opennebula-one-keys --from-file=opennebula-one-keys
```

Now you can create the reset services

```bash
kubectl create -n opennebula-test -f examples/control-plane/oned.yaml
```

#### Deploy compute nodes

Your hosts should have `libvirtd` and `qemu-kvm` installed and configured sudoersi, just place [opennebula.sudoers](https://github.com/OpenNebula/one/search?q=filename%3Aopennebula.sudoers) for your system into `/etc/sudoers.d/opennebula`, you can do that later in your custom script.

Otherwise you can just install `opennebula-node` meta-package.

* Download [opennebula-node.yaml](examples/opennebula-node.yaml) and modify `script.sh` for your needs, you can attach storage devices, configure host network there and etc.
* Deploy daemonset:

```
kubectl create -n opennebula-test -f examples/opennebula-node.yaml
```

Now you can label your compute nodes as opennebula-nodes:

```
kubectl label node <node> opennebula-node=
```
