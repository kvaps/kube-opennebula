#!/bin/bash

# Workaround: https://github.com/OpenNebula/one/issues/4357
if [ "$HEM_INTEGRATED" = 1 ]; then
  case $2 in
    leader)
      onehem-server start
    ;;
    follower)
      onehem-server stop
    ;;
  esac
fi

set -e
echo -n "Setting pod/$HOSTNAME $1=$2 - "
CA_CERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
DATA="[{\"op\": \"add\", \"path\": \"/metadata/labels/$1\", \"value\": \"$2\"}]"
NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
URL="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT/api/v1/namespaces/$NAMESPACE/pods/$HOSTNAME"
STATUS=$(curl -o /dev/null -w '%{http_code}' -sS -m5 --cacert "$CA_CERT" -H "Authorization: Bearer $TOKEN" --request PATCH --data "$DATA" -H "Content-Type:application/json-patch+json" "$URL")

if [ $STATUS -eq 200 ]; then
  echo "Success (http_code: $STATUS)"
  exit 0
else
  echo "Fail (http_code: $STATUS)"
  exit 1
fi
