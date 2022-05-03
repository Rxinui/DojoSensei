#!/bin/sh -e

## BEGIN @Rxinui custom
RPORTD_HOST="`hostname -I | grep -o -E '192.168.[0-9]{1,3}.'`1"
API_URL="https://$RPORTD_HOST:9050"
FINGERPRINT=`curl -k -s $API_URL/fingerprint.txt`
CONNECT_URL="http://$RPORTD_HOST:9080"
CLIENT_ID="dojo-api_vbox-1"
PASSWORD="auauNZgEiVxB"
# 22 -> ssh, 7681 -> ttyd
RPORTD_REMOTES="['22','7681']" 
## END @Rxinui custom