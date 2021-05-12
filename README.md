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

## Backups and restore

Find current leader:

```
kubectl get pod -n opennebula -l role=leader
```

Perform backup:
```
kubectl exec -n opennebula -c oned <leader_pod> -- sh -c 'mysqldump -h$DB_SERVER -u$DB_USER -p$DB_PASSWD $DB_NAME | gzip -9' > opennebula-db.sql.gz
```

**To restore**, redeploy release with `--set oned.debug=true` and:
```
kubectl exec -n opennebula -i -c oned <each_oned_pod> -- sh -c 'zcat | mysql -h$DB_SERVER -u$DB_USER -p$DB_PASSWD -D$DB_NAME' < opennebula-db.sql.gz
```

then disable debug


## Upgrade notes

The minor upgrades can be performed by standard way using rolling update, however major updates must be performed by fully chart reinstallation.  
You have to remove the old chart, and install new one. No worry as your data should be saved on persistent volumes, thus new images will perform database migration on their first start.

> **Warning:** Don't forget to make backup before the upgrade!

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
