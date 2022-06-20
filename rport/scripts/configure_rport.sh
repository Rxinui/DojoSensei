#!/bin/sh
. ./scripts/env_rport.sh
client_id="936f510438b417af2c85c1fc5c0f8f19"
case $1 in
-vncserver)
    curl -k -u admin:shihan -XPUT -H "accept: application/json" "$API_URL/api/v1/clients/$client_id/tunnels?remote=5901&scheme=vnc&acl=172.20.0.1&http_proxy=true"
    exit 0
    ;;
-ttyd)
    curl -k -u admin:shihan -XPUT -H "accept: application/json" "$API_URL/api/v1/clients/$client_id/tunnels?remote=7681&scheme=http&acl=172.20.0.1"
    exit 0
    ;;
esac
