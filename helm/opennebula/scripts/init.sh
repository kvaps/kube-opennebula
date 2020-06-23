#!/bin/bash
set -o pipefail

# Fatal error
fatal() {
    >&2 echo -en "ERROR:\t"
    >&2 echo "$1"
    exit 1
}

# Information message
info() {
    echo -en "INFO:\t"
    echo "$1"
}

cleanup() {
  exec 3>&2
  exec 2> /dev/null

  for PID in $(jobs -p | tac); do
    kill $PID > /dev/null 2>&1

    local counter=0
    while ps $PID > /dev/null 2>&1; do
      let counter=counter+1
      if [ $counter -gt 10 ]; then
        kill -9 $PID > /dev/null 2>&11
        break
      fi
      sleep 1
    done
  done

  exec 2>&3
  exec 3>&-     
}

# Parses option between square brackets (eg. DB = [ DB_BACKEND = "mysql" ] )
parse_opt() {
  sed 's/\(.*\)#.*/\1/g' | sed -n 's/.*'"$1"' *= *"\?\([^ ,"]\+\)"\?.*/\1/p'
}

# Sets DB_BACKEND, DB_SERVER, DB_PORT, DB_USER, DB_PASSWD, DB_NAME environment variables
load_db_config() {
  if [ ! -f /config/oned.conf ]; then
    fatal "/config/oned.conf does not exists"
  fi
  local DB_CONFIG=$(awk '/^[^#]*DB *= *\[/,/]/' /config/oned.conf)
  DB_BACKEND=${DB_BACKEND:-$(echo "$DB_CONFIG" | parse_opt BACKEND)}
  DB_SERVER=${DB_SERVER:-$(echo "$DB_CONFIG" | parse_opt SERVER)}
  DB_PORT=${DB_PORT:-$(echo "$DB_CONFIG" | parse_opt PORT)}
  DB_USER=${DB_USER:-$(echo "$DB_CONFIG" | parse_opt USER)}
  DB_PASSWD=${DB_PASSWD:-$(echo "$DB_CONFIG" | parse_opt PASSWD)}
  DB_NAME=${DB_NAME:-$(echo "$DB_CONFIG" | parse_opt NAME)}
  DB_CONNECTIONS=${DB_CONNECTIONS:-$(echo "$DB_CONNECTIONS" | parse_opt CONNECTIONS)}
  if [ "$DB_PORT" = "0" ]; then
    DB_PORT="3306"
  fi
  case "$DB_BACKEND" in
    sqlite)
      return
      ;;
    mysql)
      # load defaults
      DB_SERVER=${DB_SERVER:-127.0.0.1}
      DB_PORT=${DB_PORT:-3306}
      DB_USER=${DB_USER:-oneadmin}
      DB_PASSWD=${DB_PASSWD:-oneadmin}
      DB_CONNECTIONS=${DB_CONNECTIONS:-50}
      ;;
    '')
      fatal "can not get database backend form config"
      ;;
    *)
      fatal "only mysql and sqlite backends are supported"
      ;;
  esac
}

# Sets FEDERATION_MODE, FEDERATION_ZONE_ID, FEDERATION_SERVER_ID, FEDERATION_MASTER_ONED environment variables
load_federation_config(){
  if [ ! -f /config/oned.conf ]; then
    fatal "/config/oned.conf does not exists"
  fi
  local FEDERATION_CONFIG=$(awk '/^[^#]*FEDERATION *= *\[/,/]/' /config/oned.conf)

  FEDERATION_MODE=${FEDERATION_MODE:-$(echo "$FEDERATION_CONFIG" | parse_opt MODE)}
  FEDERATION_ZONE_ID=${FEDERATION_ZONE_ID:-$(echo "$FEDERATION_CONFIG" | parse_opt ZONE_ID)}
  FEDERATION_SERVER_ID=${FEDERATION_SERVER_ID:-$(echo "$FEDERATION_CONFIG" | parse_opt SERVER_ID)}
  FEDERATION_MASTER_ONED=${FEDERATION_MASTER_ONED:-$(echo "$FEDERATION_CONFIG" | parse_opt MASTER_ONED)}

  if ! [[ "$FEDERATION_ZONE_ID" =~ ^[0-9]+$ ]]; then
    fatal "can not get ZONE_ID from config"
  fi

  if [ "$FEDERATION_MODE" != "STANDALONE" ]; then
    fatal "MODE is not set to STANDALONE"
  elif [ "$FEDERATION_SERVER_ID" != "-1" ]; then
    fatal "SERVER_ID is not set to -1"
  fi
}

# Sets LOCAL_VERSION, NEW_VERSION environment variables
load_version_info() {
  case "$DB_BACKEND" in
    sqlite)
      if [ -f /var/lib/one/one.db ]; then
        LOCAL_VERSION=$(onedb version -s /var/lib/one/one.db | awk '$1 == "Local:" {print $2}')
        if [ $? -ne 0 ]; then
          fatal "can not connect to sqlite database"
        fi
      fi
      ;;
    mysql)
      MYSQL_OPTS=$(mktemp)
      echo -e "[client]\npassword=$DB_PASSWD" > "$MYSQL_OPTS"

      RETRY=1
      until DB_TABLES="$(mysql --defaults-file="$MYSQL_OPTS" -u "$DB_USER" -h "$DB_SERVER" -P "$DB_PORT" "$DB_NAME" -N -B -e "SHOW TABLES like 'local_db_versioning'" 2>/dev/null)"; do
        info "can not connect to mysql database mysql://$DB_USER@$DB_SERVER:$DB_PORT/$DB_NAME (try $((RETRY++)))"
        sleep 10
      done
      unset RETRY

      LOCAL_VERSION=$(mysql --defaults-file="$MYSQL_OPTS" -u "$DB_USER" -h "$DB_SERVER" -P "$DB_PORT" "$DB_NAME" -N -B -e 'SELECT version FROM local_db_versioning WHERE oid=(SELECT MAX(oid) FROM local_db_versioning)' 2>/dev/null)
      if [ $? -ne 0 ] && [ "$DB_TABLES" = "local_db_versioning" ]; then
        fatal "local_db_versioning exists but have no versions"
      fi
      rm -f "$MYSQL_OPTS"
      ;;
    '')
      fatal "Database information is not loaded"
      ;;
    *)
      fatal "Only sqlite and mysql backend support gathering version info"
      ;;
  esac
  NEW_VERSION=$(ls -1 /usr/lib/one/ruby/onedb/local  | sed -n 's/^.*_to_\(.*\)\.rb$/\1/p' | sort -V | tail -n1)
  if [ -z "$NEW_VERSION" ]; then
    fatal "can not find new version number"
  fi
}

# Performing OpenNebula database upgrade
perform_upgrade() {
  if [ -z "$DB_BACKEND" ]; then
    fatal "Database information is not loaded"
  fi
  if [ -z "$NEW_VERSION" ]; then
    fatal "Version information is not loaded"
  fi

  if [ -z "$LOCAL_VERSION" ]; then
    fatal "Failed to get local version for database"
  elif [ "$LOCAL_VERSION" = "$NEW_VERSION" ]; then
    info "Database schema is up to date"
    return 0
  fi

  NEWER_VERSION=$(echo -e "$LOCAL_VERSION\n$NEW_VERSION" | sort -V | tail -n1)

  if [ "$NEWER_VERSION" = "$LOCAL_VERSION" ]; then
    fatal "Database version $LOCAL_VERSION is higher than $NEW_VERSION."
  elif [ "$NEWER_VERSION" = "$NEW_VERSION" ]; then
    info "Database version $LOCAL_VERSION is lower than $NEW_VERSION. Performing upgrade..."

    case "$DB_BACKEND" in
      sqlite)
        onedb upgrade -s /var/lib/one/one.db
        if [ $? -ne 0 ]; then
          fatal "failed upgrade database"
        fi
        return 0
        ;;
      mysql)
        onedb upgrade -s /var/lib/one/one.db -p "$DB_PASSWD" -u "$DB_USER" -S "$DB_SERVER" -P "$DB_PORT" -d "$DB_NAME"
        if [ $? -ne 0 ]; then
          fatal "failed upgrade database"
        fi
        return 0
        ;;
      '')
        fatal "Database information is not loaded"
        ;;
      *)
        fatal "Only sqlite and mysql backend support upgrade"
        ;;
    esac
    if [ $? -ne 0 ]; then
      fatal "database schema migration was failed"
    fi
  fi
}

# Sets MY_ID
load_my_id(){
  MY_ID=$(echo "$HOSTNAME" | awk -F- '{print $NF}')
  if ! [[ "$MY_ID" =~ ^[0-9]+$ ]]; then
    fatal "hostname does not contain instance_id suffix"
  fi
}

# Removes existing database
drop_db(){
  case "$DB_BACKEND" in
    sqlite)
      rm -f "$(readlink -f /var/lib/one/one.db)"
      ;;
    mysql)
      MYSQL_OPTS=$(mktemp)
      echo -e "[client]\npassword=$DB_PASSWD" > "$MYSQL_OPTS"
      mysql --defaults-file="$MYSQL_OPTS" -u "$DB_USER" -h "$DB_SERVER" -P "$DB_PORT" -e "DROP DATABASE $DB_NAME;"
      mysql --defaults-file="$MYSQL_OPTS" -u "$DB_USER" -h "$DB_SERVER" -P "$DB_PORT" -e "CREATE DATABASE $DB_NAME;"
      rm -f "$MYSQL_OPTS"
      ;;
    '')
      fatal "Database information is not loaded"
      ;;
    *)
      fatal "Only sqlite and mysql backend support cleanup"
      ;;
  esac
}

# Creates new cluster
bootstrap_cluster(){
   rm -f \
     /var/lib/one/.one/ec2_auth \
     /var/lib/one/.one/occi_auth \
     /var/lib/one/.one/oneflow_auth \
     /var/lib/one/.one/onegate_auth \
     /var/lib/one/.one/sunstone_auth

   setup_logging
   info "starting oned"
   oned -f &
   ONED_PID="$!"

   sleep 5
   until onezone list >/dev/null 2>&1; do
     if ! kill -0 "$ONED_PID" >/dev/null 2>&1; then
       drop_db
       fatal "oned process is dead"
     fi
     info "oned is not ready. waiting 5 sec"
     sleep 5
   done

   info "adding $HOSTNAME to zone $FEDERATION_ZONE_ID"
   MY_XMLRPC="http://$(hostname -f | cut -d. -f-2):${ONE_PORT}/RPC2"
   onezone server-add "$FEDERATION_ZONE_ID" --name "$HOSTNAME" --rpc "$MY_XMLRPC"
   if [ $? -ne 0 ]; then
     drop_db
     fatal "error adding $HOSTNAME to zone $FEDERATION_ZONE_ID"
   fi

   info "setting serveradmin password"
   SERVERADMIN_PASSWORD_FILE=$(mktemp)
   cat /secrets/sunstone_auth | cut -d: -f2 > "$SERVERADMIN_PASSWORD_FILE"
   oneuser passwd 1 --sha256 -r "$SERVERADMIN_PASSWORD_FILE"
   if [ $? -ne 0 ]; then
     fatal "error setting serveradmin password"
   fi
   rm -f "$SERVERADMIN_PASSWORD_FILE"

   info 'stopping oned'
   cleanup
   info 'oned stopped'

   info "bootstrap procedure finished"
}

# Joining node to the existing cluster
bootstrap_node(){
  info "checking connection"
  ONE_XMLRPC="$LEADER_XMLRPC" onezone show "$FEDERATION_ZONE_ID" >/dev/null
  if [ $? -ne 0 ]; then
    fatal "can not get zone $FEDERATION_ZONE_ID from $LEADER_XMLRPC"
  fi

  wait_previous_host
  wait_leader

  info "downloading data from mysql://$DB_USER@$LEADER_IP:$DB_PORT/$DB_NAME"
  MYSQL_OPTS=$(mktemp)
  echo -e "[client]\npassword=$DB_PASSWD" > "$MYSQL_OPTS"
  mysqldump --defaults-file="$MYSQL_OPTS" --single-transaction=TRUE -u "$DB_USER" -h "$LEADER_IP" -P "$DB_PORT" "$DB_NAME" | \
    mysql --defaults-file="$MYSQL_OPTS" -u "$DB_USER" -h "$DB_SERVER" -P "$DB_PORT" "$DB_NAME"
  if [ $? -ne 0 ]; then
    fatal "can not bootstrap database"
  else
    info "database succesfully bootstraped"
  fi
  rm -f "$MYSQL_OPTS"

  MY_SERVER_ID="$(ONE_XMLRPC="$LEADER_XMLRPC" onezone show "$FEDERATION_ZONE_ID" -x | /var/lib/one/remotes/datastore/xpath.rb "/ZONE/SERVER_POOL/SERVER[NAME=\"$HOSTNAME\"]/ID)" | tr -d '\0')"
  if [ -n "$MY_SERVER_ID" ]; then
    info "$HOSTNAME already member of zone $FEDERATION_ZONE_ID, reseting"
    ONE_XMLRPC="$LEADER_XMLRPC" onezone server-reset "$FEDERATION_ZONE_ID" "$MY_SERVER_ID"
  else
    info "adding $HOSTNAME to zone $FEDERATION_ZONE_ID via $LEADER_XMLRPC"
    MY_XMLRPC="http://$(hostname -f | cut -d. -f-2):${ONE_PORT}/RPC2"
    ONE_XMLRPC="$LEADER_XMLRPC" onezone server-add "$FEDERATION_ZONE_ID" --name "$HOSTNAME" --rpc "$MY_XMLRPC"
    if [ $? -ne 0 ]; then
      drop_db
      fatal "can not add server to zone $FEDERATION_ZONE_ID via $LEADER_XMLRPC"
    fi
    # Sometimes zone have missing server after deploy, we need force syncronize server list to avoid this situations
    info "fetching server list for zone $FEDERATION_ZONE_ID from mysql://$DB_USER@$LEADER_IP:$DB_PORT/$DB_NAME"
    MYSQL_OPTS=$(mktemp)
    echo -e "[client]\npassword=$DB_PASSWD" > "$MYSQL_OPTS"
    mysqldump --defaults-file="$MYSQL_OPTS" --single-transaction=TRUE -u"$DB_USER" -h "$LEADER_IP" -P "$DB_PORT" "$DB_NAME" zone_pool --where="oid = $FEDERATION_ZONE_ID" --replace | \
      mysql --defaults-file="$MYSQL_OPTS" -u "$DB_USER" -h "$DB_SERVER" -P "$DB_PORT" "$DB_NAME"
    if [ $? -ne 0 ]; then
      drop_db
      fatal "can not syncronize server list for zone $FEDERATION_ZONE_ID from mysql://$DB_USER@$LEADER_IP:$DB_PORT/$DB_NAME"
    fi
  fi
}

# Waits for leader, sets LEADER_IP and LEADER_XMLRPC
wait_leader() {
  local MAX_RETRIES="$1"
  local RETRY=0

  LEADER_IP=
  LEADER_SVC=${LEADER_SVC:-$(hostname -d | awk -F. '{print $1}' | sed 's/-servers$/-headless/')}
  info "resolving $LEADER_SVC"

  until [ -n "$LEADER_IP" ]; do
    LEADER_OUT=$(getent hosts "$LEADER_SVC")
    LEADER_IP=$(echo "$LEADER_OUT" | awk 'NR=1 {print $1}')
    LEADER_DOMAIN=$(echo "$LEADER_OUT" | awk 'NR=1 {print $2}' | awk -F. '{print $3}')
    LEADER_COUNT=$(echo "$LEADER_IP" | wc -l)

    LEADER_XMLRPC="http://${LEADER_IP}:${ONE_PORT}/RPC2"

    if [ -z "$LEADER_IP" ]; then
      info "current leader not found. waiting 10 sec (try ${RETRY:-0}${MAX_RETRIES:+/$MAX_RETRIES})"
      if [ "$RETRY" = "$MAX_RETRIES" ]; then
        info "leader not found."
        return 1
      fi
      RETRY=$((RETRY+1))
      sleep 10
    elif [ "$LEADER_COUNT" != "1" ]; then
      fatal "multiple leaders found: $(echo $LEADER_IP | tr '\n' ' ')"
    elif [ "$LEADER_DOMAIN" != "svc" ]; then
      fatal "$LEADER_SVC is not a kubernetes service"
    fi
  done
 
  info "leader found. ($LEADER_IP)"
}

wait_previous_host(){
  local RETRY=0
  if [ "$FEDERATION_SERVER_ID" != "0" ]; then
    PREVIOUS_HOSTNAME="${HOSTNAME%-*}-$((FEDERATION_SERVER_ID-1))"
    until [[ "$(ONE_XMLRPC="$LEADER_XMLRPC" onezone show "$FEDERATION_ZONE_ID" -x | /var/lib/one/remotes/datastore/xpath.rb "/ZONE/SERVER_POOL/SERVER[NAME=\"$PREVIOUS_HOSTNAME\"]/STATE)" | tr -d '\0')" =~ ^(2|3)$ ]]; do
      info "waiting until $PREVIOUS_HOSTNAME be deployed (try $((RETRY++)))"
      sleep 10
    done
  fi
}

# Bootstraps new host
perform_bootstrap() {
  if [ -z "$DB_BACKEND" ]; then
    fatal "Database information is not loaded"
  fi
  if [ -z "$FEDERATION_ZONE_ID" ]; then
    fatal "Federation information is not loaded"
  fi

  # remove DB = [], take PORT
  ONE_PORT=$(awk -v RS='\n[^#\n]*DB = \\[[^]]*]' -v ORS= '1;NR==1{print}' /config/oned.conf | sed -n 's/^[^#]*PORT *= \([0-9]\+\).*/\1/p')
  if ! [[ "$ONE_PORT" =~ ^[0-9]+$ ]]; then
    fatal "can not read OpenNebula XML-RPC port from config"
  fi

  info "starting bootstrap procedure"
  if [ "$FEDERATION_SERVER_ID" -ne "0" ] && [ "$DB_BACKEND" != 'mysql' ]; then
    fatal "Only mysql backend support joining multiple instances"
  fi

  # If CREATE_CLUSTER=1 set, allow to initialize database from first pod, otherwise always wait for leader
  if [ "${CREATE_CLUSTER:-0}" = "1" ] && [ "$FEDERATION_SERVER_ID" -eq "0" ]; then
    wait_leader 3
    info "creating new cluster"
    bootstrap_cluster
    return $?
  else
    wait_leader
    bootstrap_node
  fi

  rm -f "$MYSQL_OPTS"
  info "bootstrap procedure finished"
}

# Injects database config into streamed oned.conf file
inject_db_config() {
  if [ -z "$DB_BACKEND" ]; then
    fatal "Database information is not loaded"
  fi

  awk -v RS='\n[^#\n]*DB = \\[[^]]*]' \
    -v ORS= '1;NR==1{printf "\nDB = [ BACKEND = \"'"${DB_BACKEND}\\\"${DB_SERVER:+,\n       SERVER  = \\\"${DB_SERVER}\\\"}${DB_PORT:+,\n       PORT    = ${DB_PORT}}${DB_USER:+,\n       USER    = \\\"${DB_USER}\\\"}${DB_PASSWD:+,\n       PASSWD  = \\\"${DB_PASSWD}\\\"}${DB_NAME:+,\n       DB_NAME = \\\"${DB_NAME}\\\"}${DB_CONNECTIONS:+,\n       CONNECTIONS = ${DB_CONNECTIONS}}${DB_ENCODING:+,\n       ENCODING = \\\"${DB_ENCODING}\\\"}"'\n]"}'
}

# Injects federation config into streamed oned.conf file
inject_federation_config() {
  if [ -z "$FEDERATION_ZONE_ID" ]; then
    fatal "Federation information is not loaded"
  fi

  awk -v RS='\n[^#\n]*FEDERATION = \\[[^]]*]' \
    -v ORS= '1;NR==1{printf "\nFEDERATION = [\n    MODE          = \"'"$FEDERATION_MODE"'\",\n    ZONE_ID       = '"$FEDERATION_ZONE_ID"',\n    SERVER_ID     = '"$FEDERATION_SERVER_ID"',\n    MASTER_ONED   = \"'"$FEDERATION_MASTER_ONED"'\"\n]"}'
}

# Setups keys for opennebula
setup_keys(){
  info "setup keys"
  mkdir -p "/var/lib/one/.one"
  rm -rf /var/lib/one/.one/*
  for FILE in \
    ec2_auth \
    occi_auth \
    one_auth \
    one_key \
    oneflow_auth \
    onegate_auth \
    sunstone_auth
  do
    if [ ! -f "/secrets/${FILE}" ]; then
      fatal "/secrets/${FILE} does not exists"
    fi
    cat "/secrets/${FILE}" > "/var/lib/one/.one/${FILE}"
    if [ $? -ne 0 ]; then
      fatal "error copying /secrets/${FILE} to /var/lib/one/.one/${FILE}"
    fi
  done
}

# Setups oned.conf and runs injectiors from the argumets
setup_config(){
  info "setup oned.conf ${*:+[$*]}"
  for i in "$@"; do
    local INJECT_FUNCTIONS+=" | inject_${i}_config"
  done
  eval "cat /config/oned.conf $INJECT_FUNCTIONS" > /etc/one/oned.conf
  if [ $? -ne 0 ]; then
    fatal "error copying /config/oned.conf to /etc/one/oned.conf"
  fi
}

# Sets up logging to stdout
setup_logging(){
  for i in oned.log sched.log onehem.log sunstone.log novnc.log onegate.log oneflow.log; do ln -sf "/proc/1/fd/1" "/var/log/one/$i"; done
}

# Prints usage and exit
usage() {
  cat <<EOT

USAGE:
  $0 <action>

ACTIONS:
  config [db] [federation]     Setup oned.conf and keys
  bootstrap                    Perform the bootstrap procedure
  upgrade                      Perform the upgrade procedure
  start                        Setup oned.conf and keys, perform bootstrap (or upgrade) and then start oned
  debug                        Setup oned.conf and keys, then do nothing

OPTIONS:
  --create-cluster             Allow to bootstrap new cluster
  --leader <server_id>         Specified federation server_id will force to run in solo mode

EOT
  exit 1
}

# Loads vars and defaults
init() {
  trap cleanup EXIT
  info "initializing"
  setup_logging
  load_db_config
  load_federation_config
  load_version_info

  # Setup sqlite path
  if [ "$DB_BACKEND" = "sqlite" ]; then
    ln -sf /data/one.db /var/lib/one/one.db
  fi

  setup_keys

  if [ -n "$LEADER_SERVER_ID" ] && [ "$LEADER_SERVER_ID" -lt 0 ] 2>/dev/null; then
    fatal "federation server_id must be a number"
  fi

  # Override SERVER_ID by MY_ID
  load_my_id
  if [ "${LEADER_SERVER_ID}" = "$MY_ID" ]; then
    info "Solo mode requested"
    FEDERATION_SERVER_ID="-1"
  else
    FEDERATION_SERVER_ID="$MY_ID"
  fi

}

load_keys() {
  while [ $# -gt 0 ]; do
    case $1 in
    --create-cluster)
      CREATE_CLUSTER="1"
      shift
      ;;
    --leader)
      if [ -n "$2" ] && [ "$2" -ge 0 ] 2>/dev/null; then
        LEADER_SERVER_ID="$2"
      else
        fatal "Specify exactly one federation server_id to run in solo mode"
      fi
      shift
      shift
      ;;
    --*)
      usage
      ;;
    *)
      if [ -n "$ACTION" ]; then
        if [ "$ACTION" = "config" ]; then
          EXTRA_ARGS+=" $1"
          shift
          continue
        else
          usage
        fi
      fi
      ACTION="$1"
      shift
      ;;
    esac
  done
  if [ -z "$ACTION" ]; then
    usage
  fi
}

main() {
  load_keys "$@"
  case $ACTION in
    config)
      init
      setup_config $EXTRA_ARGS
      exit $?
      ;;
    upgrade)
      init
      setup_config db federation
      perform_upgrade
      ;;
    bootstrap)
      init
      setup_config db
      perform_bootstrap
      setup_config db federation
      ;;
    start)
      init
      if [ -n "$LOCAL_VERSION" ]; then
        setup_config db federation
        perform_upgrade
      else
        setup_config db
        perform_bootstrap
        setup_keys
        setup_config db federation
      fi
      info "starting opennebula"
      oned -f
      ;;
    debug)
      init
      setup_config db federation
      info "doing nothing (debug mode requested)"
      sleep infinity
      ;;
    *)
      fatal "wrong action $ACTION"
      ;;
  esac
}

main "$@"
