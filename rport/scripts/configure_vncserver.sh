#!/bin/sh
VNCSERVER_BIN="/opt/TurboVNC/bin"
echo "> Starting Turbo vncserver $VNCSERVER_BIN"
$VNCSERVER_BIN/vncserver -securitytypes none,tlsnone,x509none -verbose :1
exit 0
# runuser -u $SETUP_USER -- $VNCSERVER_BIN/vncserver -securitytypes none,tlsnone,x509none -verbose :1 
# runuser -u $SETUP_USER -- $VNCSERVER_BIN/vncserver -securitytypes none,tlsnone,x509none -xstartup $VNCSERVER_BIN/xstartup.turbovnc -verbose :1 