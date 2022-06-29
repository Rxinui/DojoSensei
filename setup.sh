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

process_install_or_uninstall(){
    action=$1 # either install,uninstall
    shift
    while [[ $# -ne 0 ]]; do
        ls ./$1 >>/dev/null
        if [[ $? -ne 0 ]]; then
            log_error "Package '$1' is not recognized by DojoSensei."
            exit 2
        fi
        cd $1 && ./setup.sh ${action} && cd ..
        shift
    done
}

process_configure(){
    shift
    ls ./$1 >>/dev/null
    if [[ $? -ne 0 ]]; then
        log_error "Package '$1' is not recognized by DojoSensei."
        exit 2
    fi
    cd $1 && shift && $PWD/setup.sh c $@ && cd ..
}

if [[ -f "./.env" ]]; then
    log_info "Loading .env file..."
    . .env
fi
if [[ -z $DOJO_SSH_PUBKEY ]]; then
    log_error "Must set the DojoPlateforme's ssh public key with DOJO_SSH_PUBKEY env."
    log_error "DOJO_SSH_PUBKEY is required inside <.ssh/authorized_keys> of every VMs"
    log_error "to enable DojoPlateforme to have access to them."
    exit 2
fi
if [[ -z $HOST_SSH_DIR ]]; then
    HOST_SSH_DIR="~/.ssh" # default ssh dir
    log_info "HOST_SSH_DIR is not set. Default value used is '$HOST_SSH_DIR'"
fi
case $1 in
"install"|"i")
    if [[ $# -lt 2 ]]; then
        log_error "Must specify the package to install"
        exit 2
    fi
    grep "$DOJO_SSH_PUBKEY" "$HOST_SSH_DIR/authorized_keys"
    if [[ $? -ne 0 ]]; then
        log_info "Inserting DOJO_SSH_PUBKEY to $HOST_SSH_DIR/authorized_keys..."
        echo "$DOJO_SSH_PUBKEY" >> "$HOST_SSH_DIR/authorized_keys"
    fi
    # Run package setup.sh script to install
    log_info "Processing action 'install'..."
    process_install_or_uninstall $@
    ;;
"configure"|"c")
    if [[ $# -lt 2 ]]; then
        log_error "Must specify the package to configure"
        exit 2
    fi
    log_info "Processing action 'configure'..."
    process_configure $@
    ;;
"uninstall"|"u")
    if [[ $# -lt 2 ]]; then
        log_error "Must specify the package to uninstall"
        exit 2
    fi
    grep "$DOJO_SSH_PUBKEY" "$HOST_SSH_DIR/authorized_keys"
    if [[ $? -ne 0 ]]; then
        log_info "Removing DOJO_SSH_PUBKEY from $HOST_SSH_DIR/authorized_keys..."
        sed -i "s/$DOJO_SSH_PUBKEY//g" "$HOST_SSH_DIR/authorized_keys"
    fi
    log_info "Processing action 'uninstall'..."
    process_install_or_uninstall $@
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
        ./setup.sh install <package> [... <package>] # multiple packages installation
        ./setup.sh configure <package> [OPTIONS] # single package configuration
        ./setup.sh uninstall <package> [... <package>] # multiple packages uninstallation

Options: options are case-sensitive
EOF
    ;;
esac
exit $?