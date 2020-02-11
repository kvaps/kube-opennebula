# Installation

```bash
helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm upgrade --install opennebula-nfs stable/nfs-server-provisioner -f values.yaml --wait
```
