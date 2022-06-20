#!/bin/bash

########## setup.sh ##########
# Install ttyd
# @author Rxinui
##############################

## Global Environments ##
TTYD_BIN=/opt/ttyd
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
# Install 'ttyd' in the system and create its systemd service.
##
install_ttyd() {
    log_info "Download ttyd v1.6.3 binary from official GitHub repository"
    wget -O $TTYD_BIN "https://github.com/tsl0922/ttyd/releases/download/1.6.3/ttyd.$(uname -m)" -q
    chmod 755 $TTYD_BIN
    log_info "Create systemd service for ttyd"
    cat <<EOF >/etc/systemd/system/ttyd.service
[Unit]
Description=TTYD
After=syslog.target
After=network.target

[Service]
ExecStart=$TTYD_BIN login
Type=simple
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable ttyd
}

uninstall_ttyd() {
    log_info "Uninstall ttyd package"
    rm -rf $TTYD_BIN
    log_info "Uninstall ttyd service"
    systemctl stop ttyd
    systemctl daemon-reload
    rm -f /etc/systemd/system/ttyd.service
}
###############

## Main program ##
if [ $(id -u) -ne 0 ]; then
    log_error "Please, run setup.sh as root user."
fi
case $1 in
"install" | "i")
    check_package wget
    install_ttyd
    ;;
"uninstall" | "u")
    uninstall_ttyd
    ;;

*)
    cat <<EOF
setup.sh: Use this setup script to install and configure ttyd

Usage: sudo ./setup.sh <action> [OPTIONS]


Actions: actions are case-sensitive
    install, i          Install ttyd server
    uninstall, u        Uninstall ttyd server

Options: options are case-sensitive
EOF
    ;;

esac
exit 0
##################
