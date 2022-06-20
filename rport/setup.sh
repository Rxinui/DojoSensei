#!/bin/bash


########## setup.sh ##########
# Install rport client
# @author Rxinui
##############################

RPORT_SCRIPTS_DIR="$(dirname $(realpath $0))/scripts/"
EXIT_ROOT_USER=101
EXIT_NON_ROOT_USER=100
EXIT_SETUP_USER_NULL=102

## Main Program ##
if [ $(id -u) -ne 0 ]; then
    log_error "Please, run setup.sh as root user."
fi
. $RPORT_SCRIPTS_DIR/env_rport.sh
case $1 in
"install" | "i")
    bash $RPORT_SCRIPTS_DIR/install_rport.sh -s -x -i
    ;;
"uninstall" | "u")
    bash $RPORT_SCRIPTS_DIR/install_rport.sh -u
    ;;
"configure" | "c")
    shift
    $RPORT_SCRIPTS_DIR/configure_rport.sh $1
    ;;
"dry-run" | "d")
    bash $RPORT_SCRIPTS_DIR/install_rport.sh -d
    ;;
*)
    cat <<EOF
setup.sh: Use this setup script to install and configure rport-client.

Usage: sudo ./setup.sh <action> [OPTIONS] ...

Actions: actions are case-sensitive

    install, i          Install rport client
    uninstall, u        Uninstall rport client
    configure, c        Configure rport client
    dry-run, d          Dry-run rport client

Options: options are case-sensitive

    [configure]
    --set-vncserver     Configure rport to open vnc port on rportd
    --set-ttyd          Configure rport to open ttyd port on rportd
EOF
    ;;
esac
exit 0
##################
