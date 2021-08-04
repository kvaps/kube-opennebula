#!/bin/bash

wait_tcp_port(){
  until printf "" 2>/dev/null >"/dev/tcp/$1/$2"; do
    sleep 1
  done
}

finish(){
  echo "Configuration has been successfully finished"
  exec sleep infinity
}

# Check and set corrent permissions on object
# Optional variables: user, group, chmod
fix_permissions() {
  local object=$1 id=$2
  if [ -n "$chmod" ]; then
    one${object} chmod "$id" "$chmod"
  fi

  if [ -n "$user" ]; then
    if OUTPUT="$(one${object} chown "$id" "$user")"; then
      true
    else
      RC=$?
      if ! echo "$OUTPUT" | grep -q "already owns"; then
        echo "$OUTPUT"; exit $RC
      fi
    fi
  fi

  if [ -n "$group" ]; then
    if OUTPUT="$(one${object} chgrp "$id" "$group")"; then
      true
    else
      RC=$?
      if ! echo "$OUTPUT" | grep -q "already owns"; then
        echo "$OUTPUT"; exit $RC
      fi
    fi
  fi
}

# Adds object to cluster
# Optional variables: clusters
add_to_cluster() {
  local object=$1 id=$2
  for CLUSTER in $clusters; do
    onecluster add${object} "$CLUSTER" "$id"
  done
}

configure_cluster() {
  (
    local "$@"
    echo "[cluster] $@"
    set -e

    if [ -z "$name" ]; then
      echo 'name is required'
      exit -1
    fi

    # Search cluster
    if OUTPUT="$(onecluster list -lID,NAME --csv -fNAME="$name")"; then
      ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
    else
      RC=$?; echo "$OUTPUT"; exit $RC
    fi

    CONFIG="$(mktemp)"
    trap "rm -f \"$CONFIG\"" EXIT

    # Write template
    echo "$template" > "$CONFIG"

    if [ -z "$ID" ]; then
      # New cluster
      if OUTPUT="$(onecluster create "$name")"; then
        ID="$(echo "$OUTPUT" | awk '{print $NF}' )"
        onecluster update "$ID" "$CONFIG"
      else
        RC=$?; echo "$OUTPUT"; exit $RC
      fi
    else
      # Existing cluster
      onecluster update "$ID" "$CONFIG"
    fi
  )
}

configure_image() {
  (
    set -e
    echo "[image] $@"
    local "$@"

    if [ -z "$name" ]; then
      echo 'name is required'
      exit -1
    fi
    if [ -z "$datastore" ]; then
      echo 'datastore is required'
      exit -1
    fi
    if [ -z "$path" ] && [ -z "$size" ]; then
      echo 'path (or size) is required'
      exit -1
    fi

    # Search image
    if OUTPUT="$(oneimage list -lID,USER,NAME --csv -fNAME="$name" $user)"; then
      ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
    else
      RC=$?; echo "$OUTPUT"; exit $RC
    fi

    TMPNAME="tmp-$(cat /proc/sys/kernel/random/uuid)"
    CONFIG="$(mktemp)"
    trap "rm -f \"$CONFIG\"" EXIT

    # Write template
    echo "$template" > "$CONFIG"

    if [ -z "$ID" ]; then
      # New image
      echo "NAME=\"$TMPNAME\"" >> "$CONFIG"
      if [ -n "$path" ]; then
        echo "PATH=\"$path\"" >> "$CONFIG"
      fi
      if [ -n "$size" ]; then
        echo "SIZE=\"$size\"" >> "$CONFIG"
      fi
      if [ -n "$type" ]; then
        echo "TYPE=\"$type\"" >> "$CONFIG"
      fi
      if OUTPUT="$(oneimage create -d "$datastore" "$CONFIG")"; then
        ID="$(echo "$OUTPUT" | awk '{print $NF}' )"
      else
        RC=$?; echo "$OUTPUT"; exit $RC
      fi
      oneimage unlock "$ID"
      fix_permissions image "$ID"
      oneimage rename "$ID" "$name"
    else
      # Existing image
      OUTPUT="$(oneimage show -x "$ID")"
      if echo "$OUTPUT" | grep -q '<STATE>5</STATE>'; then
        echo 'image in error state!'
        exit -1
      fi
      oneimage update "$ID" "$CONFIG"
      if [ -n "$type" ]; then
        oneimage chtype "$ID" "$type"
      fi
      fix_permissions image "$ID"
    fi
  )
}

configure_datastore() {
  (
    set -e
    echo "[datastore] $@"
    local "$@"
    if [ -z "$name" ]; then
      echo 'name is required'
      exit -1
    fi
    if [ -z "$template" ]; then
      echo 'template is required'
      exit -1
    fi

    # Search datastore
    if OUTPUT="$(onedatastore list -lID,USER,NAME --csv -fNAME="$name")"; then
      ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
    else
      RC=$?; echo "$OUTPUT"; exit $RC
    fi

    TMPNAME="tmp-$(cat /proc/sys/kernel/random/uuid)"
    CONFIG="$(mktemp)"
    trap "rm -f \"$CONFIG\"" EXIT

    # Write template
    echo "$template" > "$CONFIG"

    if [ -z "$ID" ]; then
      # New datastore
      echo "NAME=\"$TMPNAME\"" >> "$CONFIG"
      if OUTPUT="$(onedatastore create "$CONFIG")"; then
        ID="$(echo "$OUTPUT" | awk '{print $NF}' )"
      else
        RC=$?; echo "$OUTPUT"; exit $RC
      fi
      fix_permissions datastore "$ID"
      onedatastore rename "$ID" "$name"
      add_to_cluster datastore "$ID"
    else
      # Existing datastore
      onedatastore update "$ID" "$CONFIG"
      fix_permissions datastore "$ID"
      add_to_cluster datastore "$ID"
    fi
  )
}

configure_group() {
  (
    set -e
    echo "[group] $@"
    local "$@"
    if [ -z "$name" ]; then
      echo 'name is required'
      exit -1
    fi

    # Search group
    if OUTPUT="$(onegroup list -lID,NAME --csv -fNAME="$name")"; then
      ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
    else
      RC=$?; echo "$OUTPUT"; exit $RC
    fi

    CONFIG="$(mktemp)"
    trap "rm -f \"$CONFIG\"" EXIT

    if [ -z "$ID" ]; then
      # New group
      if OUTPUT="$(onegroup create "$name")"; then
        ID="$(echo "$OUTPUT" | awk '{print $NF}' )"
      else
        RC=$?; echo "$OUTPUT"; exit $RC
      fi
    fi

    if [ -n "$template" ]; then
      # Write template
      echo "$template" > "$CONFIG"
      onegroup update "$ID" "$CONFIG"
    fi
  )
}

configure_hook() {
  (
    set -e
    echo "[datastore] $@"
    local "$@"
    if [ -z "$name" ]; then
      echo 'name is required'
      exit -1
    fi
    if [ -z "$template" ]; then
      echo 'template is required'
      exit -1
    fi

    # Search hook
    if OUTPUT="$(onehook list -lID,NAME --csv -fNAME="$name")"; then
      ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
    else
      RC=$?; echo "$OUTPUT"; exit $RC
    fi

    TMPNAME="tmp-$(cat /proc/sys/kernel/random/uuid)"
    CONFIG="$(mktemp)"
    trap "rm -f \"$CONFIG\"" EXIT

    # Write template
    echo "$template" > "$CONFIG"

    if [ -z "$ID" ]; then
      # New hook
      echo "NAME=\"$TMPNAME\"" >> "$CONFIG"
      if OUTPUT="$(onehook create "$CONFIG")"; then
        ID="$(echo "$OUTPUT" | awk '{print $NF}' )"
      else
        RC=$?; echo "$OUTPUT"; exit $RC
      fi
      onehook rename "$ID" "$name"
    else
      # Existing hook
      onehook update "$ID" "$CONFIG"
    fi
  )
}


configure_marketplace() {
  (
    set -e
    echo "[marketplace] $@"
    local "$@"
    if [ -z "$name" ]; then
      echo 'name is required'
      exit -1
    fi

    # Search market
    if OUTPUT="$(onemarket list -lID,NAME --csv -fNAME="$name")"; then
      ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
    else
      RC=$?; echo "$OUTPUT"; exit $RC
    fi

    CONFIG="$(mktemp)"
    trap "rm -f \"$CONFIG\"" EXIT

    # Write template
    echo "$template" > "$CONFIG"

    if [ -z "$ID" ]; then
      # New market
      echo "NAME=\"$name\"" >> "$CONFIG"
      if OUTPUT="$(onemarket create "$CONFIG")"; then
        ID="$(echo "$OUTPUT" | awk '{print $NF}' )"
      else
        RC=$?; echo "$OUTPUT"; exit $RC
      fi
    else
      # Existing market
      onemarket update "$ID" "$CONFIG"
    fi
  )
}

configure_template() {
  (
    set -e
    echo "[template] $@"
    local "$@"
    if [ -z "$name" ]; then
      echo 'name is required'
      exit -1
    fi
    if [ -z "$template" ]; then
      echo 'template is required'
      exit -1
    fi

    # Search template
    if OUTPUT="$(onetemplate list -lID,USER,NAME --csv -fNAME="$name" ${user})"; then
      ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
    else
      RC=$?; echo "$OUTPUT"; exit $RC
    fi

    TMPNAME="tmp-$(cat /proc/sys/kernel/random/uuid)"
    CONFIG="$(mktemp)"
    trap "rm -f \"$CONFIG\"" EXIT

    # Write template
    echo "$template" > "$CONFIG"

    if [ -z "$ID" ]; then
      # New template
      echo "NAME=\"$TMPNAME\"" >> "$CONFIG"
      if OUTPUT="$(onetemplate create "$CONFIG")"; then
        ID="$(echo "$OUTPUT" | awk '{print $NF}' )"
      else
        RC=$?; echo "$OUTPUT"; exit $RC
      fi
      fix_permissions template "$ID"
      onetemplate rename "$ID" "$name"
    else
      # Existing template
      onetemplate update "$ID" "$CONFIG"
      fix_permissions template "$ID"
    fi
  )
}

configure_vnet() {
  (
    set -e
    echo "[vnet] $@"
    local "$@"
    if [ -z "$name" ]; then
      echo 'name is required'
      exit -1
    fi
    if [ -z "$template" ]; then
      echo 'template is required'
      exit -1
    fi

    # Search vnet
    if OUTPUT="$(onevnet list -lID,USER,NAME --csv -fNAME="$name" $user)"; then
      ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
    else
      RC=$?; echo "$OUTPUT"; exit $RC
    fi

    TMPNAME="tmp-$(cat /proc/sys/kernel/random/uuid)"
    CONFIG="$(mktemp)"
    trap "rm -f \"$CONFIG\"" EXIT

    # Write template
    echo "$template" > "$CONFIG"

    if [ -z "$ID" ]; then
      # New vnet
      echo "NAME=\"$TMPNAME\"" >> "$CONFIG"
      if OUTPUT="$(onevnet create "$CONFIG")"; then
        ID="$(echo "$OUTPUT" | awk '{print $NF}' )"
      else
        RC=$?; echo "$OUTPUT"; exit $RC
      fi
      fix_permissions vnet "$ID"
      onevnet rename "$ID" "$name"
      add_to_cluster vnet "$ID"
    else
      # Existing vnet
      onevnet update "$ID" "$CONFIG"
      fix_permissions vnet "$ID"
      add_to_cluster vnet "$ID"
    fi
  )
}

configure_vnet_ar() {
  (
    set -e
    echo "[vnet_ar] $@"
    local "$@"
    if [ -z "$name" ]; then
      echo 'name is required'
      exit -1
    fi
    if [ -z "$template" ]; then
      echo 'template is required'
      exit -1
    fi
    if [ -z "ar_uniq_key" ]; then
      echo 'ar_uniq_key is required'
      exit -1
    fi

    # Search vnet
    if OUTPUT="$(onevnet list -lID,USER,NAME --csv -fNAME="$name" $user)"; then
      ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
    else
      RC=$?; echo "$OUTPUT"; exit $RC
    fi

    TMPNAME="tmp-$(cat /proc/sys/kernel/random/uuid)"
    CONFIG="$(mktemp)"
    trap "rm -f \"$CONFIG\"" EXIT

    # Write template
    echo "AR = [$(echo "$template" | awk NF | paste -s -d,)]" > "$CONFIG"

    # Search unique value for ar_uniq_key
    ar_uniq_val="$(sed -n 's/.*'"${ar_uniq_key}"' *= *"\?\([^",]\+\)"\?.*/\1/p' "$CONFIG")"
    if [ -z "$ar_uniq_val" ]; then
      echo "" >&2
      echo 'template have no $ar_uniq_key attribute'
      exit -1
    fi

    # Search address range
    if OUTPUT="$(onevnet show -x "$ID")"; then
      AR_ID="$(echo "$OUTPUT" | ruby -r rexml/document -e 'include REXML; p XPath.first(Document.new($stdin), "/VNET/AR_POOL/AR['"${ar_uniq_key}"'=\"'"${ar_uniq_val}"'\"]/AR_ID/text()")' | grep -o '[0-9]\+' || true)"
    else
      RC=$?; echo "$OUTPUT"; exit $RC
    fi

    if [ -z "$AR_ID" ]; then
      # New address range
      onevnet addar "$ID" "$CONFIG"
    else
      # Existing address range
      echo "AR = [AR_ID=\"$AR_ID\",$(echo "$template" | awk NF | paste -s -d,)]" > "$CONFIG"
      onevnet updatear "$ID" "$AR_ID" "$CONFIG"
    fi
  )
}

configure_vntemplate() {
  (
    set -e
    echo "[vntemplate] $@"
    local "$@"
    if [ -z "$name" ]; then
      echo 'name is required'
      exit -1
    fi
    if [ -z "$template" ]; then
      echo 'template is required'
      exit -1
    fi

    # Search vntemplate
    if OUTPUT="$(onevntemplate list -lID,USER,NAME --csv -fNAME="$name" $user)"; then
      ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
    else
      RC=$?; echo "$OUTPUT"; exit $RC
    fi

    TMPNAME="tmp-$(cat /proc/sys/kernel/random/uuid)"
    CONFIG="$(mktemp)"
    trap "rm -f \"$CONFIG\"" EXIT

    # Write template
    echo "$template" > "$CONFIG"

    if [ -z "$ID" ]; then
      # New vntemplate
      echo "NAME=\"$TMPNAME\"" >> "$CONFIG"
      if OUTPUT="$(onevntemplate create "$CONFIG")"; then
        ID="$(echo "$OUTPUT" | awk '{print $NF}' )"
      else
        RC=$?; echo "$OUTPUT"; exit $RC
      fi
      fix_permissions vntemplate "$ID"
      onevntemplate rename "$ID" "$name"
    else
      # Existing vntemplate
      onevntemplate update "$ID" "$CONFIG"
      fix_permissions vntemplate "$ID"
    fi
  )
}

configure_acl() {
  (
    set -e
    echo "[acl] $@"
    local "$@"
    if [ -z "$name" ]; then
      echo 'name is required'
      exit -1
    fi
    if [ -z "$acl" ]; then
      echo 'acl is required'
      exit -1
    fi

    if OUTPUT="$(oneacl create "$acl")"; then
      true
    elif echo "$OUTPUT" | grep -q 'already exists'; then
      true
    else
      RC=$?; echo "$OUTPUT"; exit $RC
    fi
  )
}

configure_host() {
  (
    set -e
    echo "[host] $@"
    local "$@"
    if [ -z "$name" ]; then
      echo 'name is required'
      exit -1
    fi
    if [ -z "$im_mad" ]; then
      echo 'im_mad is required'
      exit -1
    fi
    if [ -z "$vmm_mad" ]; then
      echo 'vmm_mad is required'
      exit -1
    fi

    # Search host
    if OUTPUT="$(onehost list -lID,NAME --csv -fNAME="$name")"; then
      ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
    else
      RC=$?; echo "$OUTPUT"; exit $RC
    fi

    CONFIG="$(mktemp)"
    trap "rm -f \"$CONFIG\"" EXIT

    if [ -z "$ID" ]; then
      # New host
      if OUTPUT="$(onehost create -i "$im_mad" -v "$vmm_mad" "$name")"; then
        ID="$(echo "$OUTPUT" | awk '{print $NF}' )"
      else
        RC=$?; echo "$OUTPUT"; exit $RC
      fi
      add_to_cluster host "$ID"
    fi

    if [ -n "$template" ]; then
      # Write template
      echo "$template" > "$CONFIG"
      onehost update -a "$ID" "$CONFIG"
    fi
  )
}

xmlrpc_call() {
  local method=$1 params=
  shift
  while [ $# -gt 0 ]; do
    params="$params"'<param><value><'"${1%:*}"'>'"${1#*:}"'</'"${1%:*}"'></value></param>'
    shift
  done
  wget -q -O- "${ONE_XMLRPC:-http://localhost:2633/RPC2}" --post-data '<?xml version="1.0"?><methodCall><methodName>'"$method"'</methodName><params><param><value>'"$(cat /var/lib/one/.one/one_auth)"'</value></param>'"$params"'</params></methodCall>'
}

xml_name2id() {
  grep -o '&lt;'"$1"'&gt;&lt;ID&gt;[^&]\+&lt;/ID&gt;&lt;NAME&gt;[^&]\+&lt;/NAME&gt;' | sed 's/\(&lt;[^&]\+&gt;\)\{1,2\}/,/g' | awk -F, "\$3 == \"$2\" {print \$2}"
}

# Same as configure_host, but sh compatible (works with busybox)
configure_host_lightweight() {
  (
    set -e
    echo "[host] $@"
    local "$@"
    if [ -z "$name" ]; then
      echo 'name is required'
      exit 1
    fi
    if [ -z "$im_mad" ]; then
      echo 'im_mad is required'
      exit 1
    fi
    if [ -z "$vmm_mad" ]; then
      echo 'vmm_mad is required'
      exit 1
    fi

    # Search host
    if OUTPUT="$(xmlrpc_call one.hostpool.info)"; then
      ID="$(echo "$OUTPUT" | xml_name2id HOST "$name")"
    else
      RC=$?; echo "$OUTPUT"; exit $RC
    fi

    CONFIG="$(mktemp)"
    trap "rm -f \"$CONFIG\"" EXIT

    if [ -n "$cluster" ]; then
      # check if numberic
      if [ "$cluster" -eq "$cluster" ] 2>/dev/null; then
        CLUSTER_ID="$cluster"
      else
        CLUSTER_ID=$(xmlrpc_call one.clusterpool.info | xml_name2id CLUSTER "$cluster")
        if [ -z "$CLUSTER_ID" ]; then
          echo "Could not find cluster with name $cluster"
          exit 1
        fi
      fi
    fi

    if [ -z "$ID" ]; then
      # New host
      if OUTPUT="$(xmlrpc_call one.host.allocate "string:$name" "string:$im_mad" "string:$vmm_mad" "i4:${CLUSTER_ID:--1}")"; ! echo "$OUTPUT" | grep -q '<value><boolean>1</boolean></value>'; then
        RC=$?; echo "$OUTPUT"; exit $RC
      else
        ID="$(echo "$OUTPUT" | sed -n 's|<value><i4>\([0-9]\+\)</i4></value>|\1|p')"
      fi
    else
      if [ -n "$cluster" ]; then
        if OUTPUT="$(xmlrpc_call one.cluster.addhost "i4:$CLUSTER_ID" "i4:$ID")"; ! echo "$OUTPUT" | grep -q '<value><boolean>1</boolean></value>'; then
          RC=$?; echo "$OUTPUT"; exit $RC
        fi
      fi
    fi

    if [ -n "$template" ]; then
      # Write template
      echo "$template" > "$CONFIG"
      if OUTPUT="$(xmlrpc_call one.host.update "i4:$ID" "string:$(cat "$CONFIG")" i4:1)"; ! echo "$OUTPUT" | grep -q '<value><boolean>1</boolean></value>'; then
        RC=$?; echo "$OUTPUT"; exit $RC
      fi
    fi
  )
}
