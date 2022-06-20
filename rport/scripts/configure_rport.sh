#!/bin/sh
. ./scripts/env_rport.sh
client_id=`cat /etc/machine-id`
case $1 in
--set-vncserver)
    curl -k -u admin:shihan -XPUT -H "accept: application/json" "$API_URL/api/v1/clients/$client_id/tunnels?remote=5901&scheme=vnc&acl=172.20.0.1&http_proxy=true&check_port=0"
    ;;
--set-ttyd)
    curl -k -u admin:shihan -XPUT -H "accept: application/json" "$API_URL/api/v1/clients/$client_id/tunnels?remote=7681&scheme=http&acl=172.20.0.1&check_port=0"
    ;;
esac
exit 0
