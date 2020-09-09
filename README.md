# Kube-OpenNebula

![](https://opennebula.org/wp-content/uploads/2019/04/img-logo-blue.svg)

Helm chart and OpenNebula images ready to deploy on Kubernetes

## Quick start

### Control plane

* Create namespace:
  
  ```bash
  kubectl create namespace opennebula
  ```

* Install Helm repo:

  ```bash
  helm repo add kvaps https://kvaps.github.io/charts
  ```
  
* Deploy OpenNebula:
  
  ```bash
  # download example values
  helm show values kvaps/opennebula --version 1.2.0 > values.yaml

  # install release
  helm install opennebula kvaps/opennebula --version 1.2.0 \
    --namespace opennebula \
    --set oned.createCluster=1 \
    -f values.yaml \
    --wait
  ```

### Compute nodes

* To deploy external compute node your hosts should have `libvirtd` and `qemu-kvm` installed and configured [sudoers](https://github.com/OpenNebula/one/tree/release-5.10.1/share/pkgs/sudoers).  
  However you can just [install `opennebula-node`](https://docs.opennebula.org/5.10/deployment/node_installation/kvm_node_installation.html) meta-package.

* Get OpenNebula's ssh-key, and place it to `/var/lib/one/.ssh/authorized_keys` on every node to allow OpenNebula login via ssh.
  ```bash
  kubectl exec opennebula-opennebula-oned-0 -c oned -- ssh-keygen -y -f /var/lib/one/.ssh/id_rsa
  ```

* Create new host via OpenNebula Interface.


* Check is everything is fine  
  You should be able login via ssh from oned pod to every node. You can check that by executing the following command:
  ```bash
  kubectl exec -ti opennebula-opennebula-oned-0 ssh <node>
  ```

## Customization

Sometimes you need to perform some customization, eg. update sunstone views and addtitional drivers, etc.

All these customizations could be done by updating dockerimages, you can find some examples [here](examples/prod/dockerfiles), or by simple using `extraVolumes` and `extraVolumeMounts` in chart values.

## Production setup

Production install assumes having persistent storage.

OpenNebula requires one ReadWriteOnce persistent volume per each oned-instance where database files will be stored, even [local volumes](https://kubernetes.io/blog/2019/04/04/kubernetes-1.14-local-persistent-volumes-ga/) enough for that, however it also requires one shared (ReadWriteMany) persistent volume for virtual machine logs and vnc tokens, take a look at [nfs-server-provisioner](https://github.com/helm/charts/tree/master/stable/nfs-server-provisioner) if you'r storage does not support ReadWriteMany.

Example production configuration can be found [here](examples/prod/deploy)

## Upgrade notes

The minor upgrades can be performed by standard way using rolling update, however major updates should be performed by fully chart reinstallation.
You have to remove the old chart, and install new one, however your data should be saved on persistent volumes, thus new images will perform database migration on their first start.

Perform backup:
```bash
# Find the leader pod
kubectl get pod -l role=leader
# Perform the backup
kubectl exec <leader_pod> -c oned -- bash -c 'mysqldump -h$DB_SERVER -u$DB_USER -p$DB_PASSWORD $DB_NAME | gzip -9' > backup.sql.gz
```

Minor upgrade:
```bash
helm upgrade opennebula kvaps/opennebula --version 1.2.0 \
  --namespace opennebula \
  -f values.yaml \
  --wait
```

Major upgrade:
```bash
# Remove the chart
helm remove opennebula \
  --namespace opennebula

# Deploy the new chart
helm upgrade opennebula kvaps/opennebula --version 1.2.0 \
  --namespace opennebula \
  -f values.yaml \
  --wait
```
