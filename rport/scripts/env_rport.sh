#!/bin/sh -e

## BEGIN @Rxinui custom
RPORTD_HOST="`hostname -I | grep -o -E '192.168.[0-9]{1,3}.'`1"
API_URL="https://$RPORTD_HOST:9050"
# FINGERPRINT=`curl -k -s $API_URL/fingerprint.txt`
FINGERPRINT='randomfingerprint'
CONNECT_URL="http://$RPORTD_HOST:9080"
CLIENT_ID="dojo-api_vbox-1"
PASSWORD="auauNZgEiVxB"
# 22 -> ssh, 7681 -> ttyd
RPORTD_REMOTES="['22','7681']" 
# RPORTD_REMOTES="['172.20.0.1:22','172.20.0.1:7681']" 
# only the host machine that runs rportd is allowed (172.20.0.1, from intdojonet network)
RPORTD_TUNNEL_ALLOWED="['127.0.0.0/8']"
## END @Rxinui custom