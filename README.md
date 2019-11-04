# Kube-OpenNebula

![](https://opennebula.org/wp-content/uploads/2019/04/img-logo-blue.svg)

Helm chart and OpenNebula images ready to deploy on Kubernetes

## Quick start

### Control plane

* Create namespace:
  
  ```bash
  kubectl create namespace opennebula
  ```
  
* Deploy OpenNebula:
  
  ```bash
  cd helm/opennebula
  vim values.yaml
  helm template . | kubectl apply -n opennebula -f -
  ```

### Compute nodes

* To deploy external compute node your hosts should have `libvirtd` and `qemu-kvm` installed and configured sudoers, just place [opennebula.sudoers](https://github.com/OpenNebula/one/search?q=filename%3Aopennebula.sudoers) for your system into `/etc/sudoers.d/opennebula`.<br>
  Otherwise you can just install `opennebula-node` meta-package.

* Get OpenNebula's ssh-key, and place it to `/var/lib/one/.ssh/authorized_keys` on every node to allow OpenNebula login via ssh.
  ```
  kubectl exec opennebula-oned-0 -c oned -- ssh-keygen -y -f /var/lib/one/.ssh/id_rsa
  ```

* Create new host via OpenNebula Interface.


* Check is everything is fine<br>
  You should be able login via ssh from oned pod to every node. You can check that by executing the following command:
  ```
  kubectl exec -ti opennebula-oned-0 ssh <node>
  ```
