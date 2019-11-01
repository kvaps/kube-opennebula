#!/bin/bash
[ "$(onezone show 0 -x | /var/lib/one/remotes/datastore/xpath.rb '/ZONE/SERVER_POOL/SERVER[STATE=3]/NAME)' | tr -d '\0')" = "$HOSTNAME" ]
