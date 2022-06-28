#!/bin/bash

CONFIG_FILE="/etc/rport/rport.conf"
RPORT_RELEASE="0.7.0"
RPORT_TAR_FILE="rport_${RPORT_RELEASE}_Linux_$(uname -m).tar.gz"
RPORTD_HOST="`hostname -I | grep -o -E '192.168.[0-9]{1,3}.'`1"
RPORTD_API_URL="https://$RPORTD_HOST:9050"
RPORTD_CONNECT_URL="http://$RPORTD_HOST:9080"
RPORTD_FINGERPRINT=`curl -k -s $RPORTD_API_URL/fingerprint.txt || echo ""` # will be dynamically loaded with `curl -k -s $RPORTD_API_URL/fingerprint.txt`
RPORTD_API_AUTH="dojo-api_vbox-1:auauNZgEiVxB"
## RPORTD_REMOTES="['22','7681']" # 22 -> ssh, 7681 -> ttyd
## RPORTD_TUNNEL_ALLOWED="['127.0.0.0/8']" # only the host machine that runs rportd is allowed (172.20.0.1, from intdojonet network)
