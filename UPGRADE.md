# Upgrade Notes

Find the leader pod:
```
# 5.8.5
kubectl get pod | grep opennebula-oned | grep '2/2'
# 5.10.1
kubectl get pod -l role=leader
```

Perform the backup
```
kubectl exec <leader_pod> -c oned -- bash -c 'mysqldump -h$DB_SERVER -u$DB_USER -p$DB_PASSWORD $DB_NAME | gzip -9' > backup.sql.gz
```

Remove the chart

```
helm remove <release_name> opennebula
```

Deplot the new chart

```
helm install <release_name> opennebula
```
