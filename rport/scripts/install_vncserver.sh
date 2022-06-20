#!/bin/bash

##
# Installer for VNCserver (TurboVNC)
#
# @author Rxinui
##

TURBOVNC_PACKAGE="/tmp/turbovnc_3.0_$(dpkg --print-architecture).deb"
echo "> Prepare download of '$TURBOVNC_PACKAGE'"
curl "https://deac-ams.dl.sourceforge.net/project/turbovnc/3.0/turbovnc_3.0_$(dpkg --print-architecture).deb" -o $TURBOVNC_PACKAGE
echo "> Install of '$TURBOVNC_PACKAGE'"
sudo apt install -y $TURBOVNC_PACKAGE
echo "> Add TurboVNC binaries to path"
TURBOVNC_PATH="/opt/TurboVNC/bin"
if [[ -d $TURBOVNC_PATH && $PATH != *"$TURBOVNC_PATH"* ]]; then
    export PATH=$PATH:/opt/TurboVNC/bin
    grep -o "TURBOVNC_PATH" ~/.profile && echo "TURBOVNC_PATH=$TURBOVNC_PATH
if [[ -d $TURBOVNC_PATH && \$PATH != *"$TURBOVNC_PATH"* ]]; then
    export PATH=\$PATH:$TURBOVNC_PATH
fi" >> ~/.profile
fi
echo "> '$TURBOVNC_PACKAGE' is now installed"
