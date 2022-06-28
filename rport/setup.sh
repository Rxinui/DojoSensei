#!/bin/bash

########## setup.sh ##########
# Install rport client
# @author Rxinui
##############################

RPORT_SCRIPTS_DIR="$(dirname $(realpath $0))/scripts"

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

## Main Program ##
if [ $(id -u) -ne 0 ]; then
    log_error "Please, run setup.sh as root user."
    exit 2
fi
. $RPORT_SCRIPTS_DIR/env.sh
case $1 in
"install" | "i")
    bash $RPORT_SCRIPTS_DIR/install_rport.sh
    ;;
"uninstall" | "u")
    bash $RPORT_SCRIPTS_DIR/uninstall_rport.sh
    ;;
"configure" | "c")
    shift
    if [ $# -eq 0 ]; then
        log_error "Action 'configure' expects options"
        $RPORT_SCRIPTS_DIR/configure_rport.sh -h
        exit 2
    fi
    $RPORT_SCRIPTS_DIR/configure_rport.sh $@
    ;;
"start"|"s")
    log_info "Start rport client"
    
    ;;
*)
    cat <<EOF
setup.sh: Use this setup script to install and configure rport-client.

Usage: sudo ./setup.sh <action> [OPTIONS] ...

Actions: actions are case-sensitive

    install, i          Install rport client
    uninstall, u        Uninstall rport client
    configure, c        Configure rport client

Options: options are case-sensitive

    [configure]
    --conf              Configure rport config file
    --set-vncserver     Configure rport to open vnc port on rportd
    --set-ttyd          Configure rport to open ttyd port on rportd
EOF
    ;;
esac
exit 0
##################
