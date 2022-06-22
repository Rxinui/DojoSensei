#!/bin/bash

########## setup.sh ##########
# Install TurboVNC server
# @author Rxinui
##############################

## Global Environments ##
VNCSERVER_BIN="/opt/TurboVNC/bin"
#########################

## System Functions ##

##
# Log an information message.
#
# Parameters:
#   $1: info message to log.
##
log_info() {
    echo -e "\e[36mINFO: $1\e[0m"
}

##
# Log an error message.
#
# Parameters:
#   $1: error message to log.
##
log_error() {
    echo -e "\e[31mERROR: $1\e[0m"
}
######################

## Functions ##

##
# Check if a packaged is installed on the machine.
#
# Parameters:
#   $1: package command name
##
check_package() {
    which $1 >/dev/null
    if [ $? -ne 0 ]; then
        log_error "Missing linux package $($1)"
        exit 2
    fi
}

##
# Install 'TurboVNC' in the system and update PATH env.
#
# Parameters:
#   --user, -u:         [Required] Install TurboVNC for given user. This user will be specified within the service.
#
##
install_turbovnc() {
    case $1 in
    "--user" | "-u")
        shift
        _USER=$1
        ;;
    esac
    if [[ -z $_USER ]]; then
        log_error "Must specify a user with the '--user' parameter"
        exit 2
    fi
    TURBOVNC_PACKAGE="/tmp/turbovnc_3.0_$(dpkg --print-architecture).deb"
    log_info "Prepare download of '$TURBOVNC_PACKAGE'"
    curl "https://deac-ams.dl.sourceforge.net/project/turbovnc/3.0/turbovnc_3.0_$(dpkg --print-architecture).deb" -o $TURBOVNC_PACKAGE
    log_info "Install of '$TURBOVNC_PACKAGE'"
    sudo apt install -y $TURBOVNC_PACKAGE
    log_info "Add TurboVNC binaries to path"
    TURBOVNC_PATH="/opt/TurboVNC/bin"
    if [[ -d $TURBOVNC_PATH && $PATH != *"$TURBOVNC_PATH"* ]]; then
        export PATH=$PATH:/opt/TurboVNC/bin
        grep -o "TURBOVNC_PATH" ~/.profile && echo "TURBOVNC_PATH=$TURBOVNC_PATH
    if [[ -d $TURBOVNC_PATH && \$PATH != *"$TURBOVNC_PATH"* ]]; then
        export PATH=\$PATH:$TURBOVNC_PATH
    fi" >>~/.profile
    fi
    log_info "'$TURBOVNC_PACKAGE' is now installed"
    log_info "Create TurboVNC service"
    cat <<EOF >/etc/systemd/system/turbovnc.service
[Unit]
Description=Run TurboVNC server to enable VNC protocol
ConditionFileIsExecutable=/opt/TurboVNC/bin/vncserver
After=syslog.target network.target

[Service]
Type=simple
StartLimitInterval=5
StartLimitBurst=10
ExecStartPre=/usr/bin/rm -f /tmp/.X1-lock /tmp/.X11-unix/X1
ExecStart=$VNCSERVER_BIN/vncserver -securitytypes none,tlsnone,x509none -verbose :5
StandardOutput=append:/var/log/turbovnc.log
StandardError=append:/var/log/turbovnc.log
# User=root
User=$_USER
Restart=on-failure
RestartSec=60

[Install]
WantedBy=graphical.target 
EOF
    systemctl daemon-reload
    systemctl enable turbovnc
    log_info "TurboVNC installation is done"
}

##
# Uninstall all 'TurboVNC' dependencies.
##
uninstall_turbovnc() {
    log_info "Uninstall TurboVNC"
    apt remove -y turbovnc
    log_info "Remove TurboVNC service"
    rm -f /etc/systemd/system/turbovnc.service
    systemctl daemon-reload
    systemctl disable turbovnc
    log_info "TurboVNC uninstallation is done"
}

##
# Start 'TurboVNC' server
##
start_turbovnc() {
    case $1 in
    "--user" | "-u")
        shift
        _USER=$1
        ;;
    esac
    if [[ -z $_USER ]]; then
        log_error "Must specify a user with the '--user' parameter"
        exit 2
    fi
    log_info "Starting Turbo vncserver $VNCSERVER_BIN"
    #TODO delete /tmp/ X1 files
    rm -f /tmp/.X1-lock /tmp/.X11-unix/X1
    runuser -u $_USER -- $VNCSERVER_BIN/vncserver -securitytypes none,tlsnone,x509none -verbose :5
}
###############

## Main program ##
if [ $(id -u) -ne 0 ]; then
    log_error "Please, run setup.sh as root user."
    exit 2
fi
case $1 in
"install" | "i")
    shift
    check_package curl
    install_turbovnc $@
    ;;
"uninstall" | "u")
    check_package apt
    uninstall_turbovnc
    ;;
"start" | "s")
    if [[ -d $VNCSERVER_BIN ]]; then
        shift
        start_turbovnc $@
    fi
    ;;
*)
    cat <<EOF
setup.sh: Use this setup script to install and configure TurboVNC server

Usage: sudo ./setup.sh <action> [OPTIONS]

Actions: actions are case-sensitive
    install, i          Install TurboVNC server
    uninstall, u        Uninstall TurboVNC server
    start, s            Start TurboVNC server

Options: options are case-sensitive
EOF
    ;;

esac
exit 0
##################
