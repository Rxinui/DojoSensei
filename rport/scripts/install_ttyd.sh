#!/bin/sh

##
# Installer for ttyd
#
# @author Rxinui
##
which wget >/dev/null
if [ $? -ne 0 ]; then
    echo "ERROR: missing linux package `wget`"
    exit 2
fi
wget -O /opt/ttyd "https://github.com/tsl0922/ttyd/releases/download/1.6.3/ttyd.$(uname -m)"
chmod 755 /opt/ttyd
echo "Create systemd service for ttyd"
cat << EOF > /etc/systemd/system/ttyd.service
[Unit]
Description=TTYD
After=syslog.target
After=network.target

[Service]
ExecStart=/opt/ttyd login
Type=simple
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF
exit 0