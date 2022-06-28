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

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  is_available
#   DESCRIPTION:  Check if a command is available on the system.
#    PARAMETERS:  command name
#       RETURNS:  0 if available, 1 otherwise
#----------------------------------------------------------------------------------------------------------------------
is_available() {
    if command -v "$1" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  uninstall
#   DESCRIPTION:  Uninstall everything and remove the user
#----------------------------------------------------------------------------------------------------------------------
uninstall() {
    if pgrep rportd >/dev/null; then
        log_error "You are running the rportd server on this machine. Uninstall manually."
        exit 1
    fi
    systemctl stop rport >/dev/null 2>&1 || true
    rc-service rport stop >/dev/null 2>&1 || true
    pkill -9 rport >/dev/null 2>&1 || true
    rport --service uninstall >/dev/null 2>&1 || true
    FILES="/usr/local/bin/rport
    /usr/local/bin/rport
    /etc/systemd/system/rport.service
    /etc/sudoers.d/rport-update-status
    /etc/sudoers.d/rport-all-cmd
    /usr/local/bin/tacoscript
    /etc/init.d/rport
    /var/run/rport.pid
    /etc/runlevels/default/rport"
    for FILE in $FILES; do
        if [ -e "$FILE" ]; then
            rm -f "$FILE" && log_info " [ DELETED ] File $FILE"
        fi
    done
    if id rport >/dev/null 2>&1; then
        if is_available deluser; then
            deluser --remove-home rport >/dev/null 2>&1 || true
            deluser --only-if-empty --group rport >/dev/null 2>&1 || true
        elif is_available userdel; then
            userdel -r -f rport >/dev/null 2>&1
        fi
        if is_available groupdel; then
            groupdel -f rport >/dev/null 2>&1 || true
        fi
        log_info " [ DELETED ] User rport"
    fi
    FOLDERS="/etc/rport
    /var/log/rport
    /var/lib/rport"
    for FOLDER in $FOLDERS; do
        if [ -e "$FOLDER" ]; then
            rm -rf "$FOLDER" && log_info " [ DELETED ] Folder $FOLDER"
        fi
    done
    log_info "RPort client successfully uninstalled."
}

uninstall
exit 0