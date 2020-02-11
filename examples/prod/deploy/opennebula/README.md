# Installation

```bash
helm upgrade --install opennebula ../../../../helm/opennebula -f values.yaml -f secrets.yaml --set oned.createCluster=1 --wait
```
