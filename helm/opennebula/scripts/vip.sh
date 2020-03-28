#!/bin/bash
set -e -o pipefail
CA_CERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
API_URL="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT"
ROLE_LABEL=${ROLE_LABEL:-role}
ROLE_LABEL_LEADER=${ROLE_LABEL_LEADER:-leader}
ROLE_LABEL_FOLLOWER=${ROLE_LABEL_FOLLOWER:-follower}

pcurl() {
  curl -f -k -sS --cacert "$CA_CERT" -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" "$@"
}
parse_names() {
  ruby -rjson -e "JSON.parse(STDIN.read)['items'].each {|item| puts item['metadata']['name']}"
}
label_pod() {
    echo "Setting pod/$1 ${2%%=*}=${2##*=}"
    pcurl -XPATCH -o /dev/null --data "[{\"op\": \"add\", \"path\": \"/metadata/labels/${2%%=*}\", \"value\": \"${2##*=}\"}]" -H "Content-Type:application/json-patch+json" "$API_URL/api/v1/namespaces/$NAMESPACE/pods/$1"
}

case $1 in
  leader)
    # start hem
    [ "$HEM_INTEGRATED" != 1 ] || onehem-server start || true
    # set leader
    label_pod "$HOSTNAME" "$ROLE_LABEL=$ROLE_LABEL_LEADER"
    # remove old leaders
    OLD_LEADERS="$(pcurl $CURL_PARAMS -XGET "${API_URL}/api/v1/namespaces/${NAMESPACE}/pods?labelSelector=${ROLE_LABEL}%3D${ROLE_LABEL_LEADER}" | parse_names)"
    for POD in $OLD_LEADERS; do
      if [ "$POD" != "$HOSTNAME" ]; then
        label_pod "$POD" "$ROLE_LABEL=$ROLE_LABEL_FOLLOWER"
      fi
    done
    ;;
  follower)
    # stop hem
    [ "$HEM_INTEGRATED" != 1 ] || onehem-server stop || true
    # set follower
    label_pod "$HOSTNAME" "$ROLE_LABEL=$ROLE_LABEL_FOLLOWER"
    ;;
  *)
    echo "Usage: $0 <leader|follower>"
    exit 1
    ;;
esac
