# kube-opennebula

## Create namespace

```
kubectl create namespace opennebula
```

## Generate keys

```bash
mkdir onehost-ssh-config

ssh-keygen -f onehost-ssh-config/ssh_host_rsa_key -C opennebula-node -P ''

cat > onehost-ssh-config/sshd_config <<EOT
Port 2222
ChallengeResponseAuthentication no
UsePAM yes
Subsystem sftp /usr/lib/openssh/sftp-server
HostKey /etc/ssh/ssh_host_rsa_key
EOT

kubectl create configmap -n opennebula onehost-ssh-config --from-file=onehost-ssh-config
```

```bash
mkdir oneadmin-ssh-config
ssh-keygen -f oneadmin-ssh-config/id_rsa -C oneadmin -P ''
cat oneadmin-ssh-config/id_rsa.pub > oneadmin-ssh-config/authorized_keys

cat > oneadmin-ssh-config/ssh_config <<EOT
Host *
    StrictHostKeyChecking no
    Port 2222
    User oneadmin
EOT

kubectl create configmap -n opennebula oneadmin-ssh-config --from-file=oneadmin-ssh-config
```

## Create servies

### OpenNebula-node

* Download example [opennebula-node.yaml](opennebula-node.yaml) file.
* Open with text-editor, and update your datastores.
* Deploy daemonset:

```
kubectl create -f opennebula-node.yaml
```

* mark wanted nodes for run opennebula-node daemons:

```
kubectl label node node1 opennebula-node=
```

* check your pods:
```
kubectl get pod -n opennebula -o wide
```
