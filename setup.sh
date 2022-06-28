#!/bin/bash -e


########## setup.sh ##########
# Setup script for DojoSensei
# @author Rxinui
##############################

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

if [[ -f "./.env" ]]; then
    . .env
fi
if [[ -z $DOJO_SSH_PUBKEY ]]; then
    log_error "Must set the DojoPlateforme's ssh public key with DOJO_SSH_PUBKEY env."
    log_error "DOJO_SSH_PUBKEY is required inside ~/.ssh/authorized_keys of every VMs"
    log_error "to enable DojoPlateforme to have access to them."
    exit 2
fi
if [[ -z $HOST_SSH_DIR ]]; then
    HOST_SSH_DIR="~/.ssh" # default ssh dir
    log_info "HOST_SSH_DIR is not set. Default value used is '$HOST_SSH_DIR'"
fi
case $1 in
"install"|"i")
    shift
    # Insert DOJO_SSH_PUBKEY to ~/.ssh/authorized_keys
    grep "$DOJO_SSH_PUBKEY" "$HOST_SSH_DIR/authorized_keys"
    if [[ $? -ne 0 ]]; then
        echo "$DOJO_SSH_PUBKEY" >> "$HOST_SSH_DIR/authorized_keys"
    fi
    # Run package setup.sh script to install
    while [[ $# -ne 0 ]]; do
        ls ./$1 >>/dev/null
        if [[ $? -ne 0 ]]; then
            log_error "Package '$1' is not recognized by DojoSensei."
            exit 2
        fi
        cd $1 && ./setup.sh i && cd ..
        shift
    done
    ;;
*)
    cat <<EOF
setup.sh: Use this setup script to install and configure DojoSensei's packages.

Usage: sudo ./setup.sh <action> [OPTIONS] ...

Environment:
    DOJO_SSH_PUBKEY [Required]          DojoPlateforme's ssh public key.
                                        It will be installed in host machine 
                                        to grant remote access to DojoPlateforme.
    HOST_SSH_DIR                        Host machine's SSH directory path to add
                                        DOJO_SSH_PUBKEY inside 'authorized_keys'.

Packages:
    rport                               RPort client to manage remote tunnels with rportd
    ttyd                                ttyd to share a machine's terminal over HTTP protocol
    turbovnc                            TurboVNC to share machine's graphical desktop over VNC protocol

Actions: actions are case-sensitive                                
    install, i                          Install DojoSensei's package
    uninstall, u                        Uninstall DojoSensei's package
    configure, c                        Configure DojoSensei's package

    [Usage]
        ./setup.sh install <package> [... <package>]
        ./setup.sh configure <package> [OPTIONS]
        ./setup.sh uninstall <package> [... <package>]

Options: options are case-sensitive
EOF
    ;;
esac
exit 0