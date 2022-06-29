#!/bin/bash -e

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

##
# Put an string balise to notify that raw JSON
# data will follow. Used by scripts to search
# easily JSON data and make the parsing easier.
##
######################
json_data_separator() {
    echo "@JSON_DATA@"
}
parent_path=$(dirname $(realpath $0))
. $parent_path/env.sh


version_to_int() {
    echo "$1" |
        awk -v 'maxsections=3' -F'.' 'NF < maxsections {printf("%s",$0);for(i=NF;i<maxsections;i++)printf("%s",".0");printf("\n")} NF >= maxsections {print}' |
        awk -v 'maxdigits=3' -F'.' '{print $1*10^(maxdigits*2)+$2*10^(maxdigits)+$3}'
}

enable_lan_monitoring() {
    if [ "$(version_to_int "$RPORT_RELEASE")" -lt 5008 ]; then
        # Version does not handle network interfaces yet.
        return 0
    fi
    if grep "^\s*net_[wl]" "$CONFIG_FILE"; then
        # Network interfaces already configured
        return 0
    fi
    echo "Enabling Network monitoring"
    for IFACE in /sys/class/net/*; do
        IFACE=$(basename "${IFACE}")
        [ "$IFACE" = 'lo' ] && continue
        if ip addr show "$IFACE" | grep -E -q "inet (10|192\.168|172\.16)\."; then
            # Private IP
            NET_LAN="$IFACE"
        else
            # Public IP
            NET_WAN="$IFACE"
        fi
    done
    if [ -n "$NET_LAN" ]; then
        sed -i "/^\[monitoring\]/a \ \ net_lan = ['${NET_LAN}' , '1000' ]" "$CONFIG_FILE"
    fi
    if [ -n "$NET_WAN" ]; then
        sed -i "/^\[monitoring\]/a \ \ net_wan = ['${NET_WAN}' , '1000' ]" "$CONFIG_FILE"
    fi
}

detect_interpreters() {
    if [ "$(version_to_int "$RPORT_RELEASE")" -lt 5008 ]; then
        # Version does not handle interpreters yet.
        return 0
    fi
    if grep -q "\[interpreter\-aliases\]" "$CONFIG_FILE"; then
        # Config already updated
        true
    else
        echo "Updating config with new interpreter-aliases ..."
        echo '[interpreter-aliases]' >>"$CONFIG_FILE"
    fi
    SEARCH="bash zsh ksh csh python3 python2 perl pwsh fish"
    for ITEM in $SEARCH; do
        FOUND=$(command -v "$ITEM" 2>/dev/null || true)
        if [ -z "$FOUND" ]; then
            continue
        fi
        echo "Interpreter '$ITEM' found in '$FOUND'"
        if grep -q "$ITEM.*$FOUND" "$CONFIG_FILE"; then
            echo "Interpreter '$ITEM = $FOUND' already registered."
            continue
        fi
        # Append the found interpreter to the config
        sed -i "/^\[interpreter-aliases\]/a \ \ $ITEM = \"$FOUND\"" "${CONFIG_FILE}"
    done
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  get_hostname
#   DESCRIPTION:  Try to get the hostname from various sources
#----------------------------------------------------------------------------------------------------------------------
get_hostname() {
    hostname -f 2>/dev/null && return 0
    hostname 2>/dev/null && return 0
    cat /etc/hostname 2>/dev/null && return 0
    LANG=en hostnamectl | grep hostname | grep -v 'n/a' | cut -d':' -f2 | tr -d ' '
}

configure_rport(){
    if [[ -z $DOJO_USERID ]]; then
        log_error "Must specify DOJO_USERID env or --dojo-userid option to associate host to user"
        exit 2
    fi
    if [[ -z $DOJO_WORKSHOPID ]]; then
        log_error "Must specify DOJO_WORKSHOPID env or --dojo-workshopid option to associate host to workshop"
        exit 2
    fi
    log_info "Configuring rport configuration $CONFIG_FILE..."
    log_info "Preparing configuration..."
    sed -i "s|#*server = .*|server = \"${RPORTD_CONNECT_URL}\"|g" "$CONFIG_FILE"
    sed -i "s/#*auth = .*/auth = \"${RPORTD_API_AUTH}\"/g" "$CONFIG_FILE"
    # sed -i "s/^#*remotes = .*/remotes = ${RPORTD_REMOTES}/g" "$CONFIG_FILE"
    if [ -z $RPORTD_FINGERPRINT ]; then
        # disable fingerprint security
        sed -i "s/#*fingerprint = .*/#fingerprint = \"${RPORTD_FINGERPRINT}\"/g" "$CONFIG_FILE"
    else
        sed -i "s/#*fingerprint = .*/fingerprint = \"${RPORTD_FINGERPRINT}\"/g" "$CONFIG_FILE"
    fi
    sed -i "s/#*log_file = .*C.*Program Files.*/""/g" "$CONFIG_FILE"
    sed -i "s/#*log_file = /log_file = /g" "$CONFIG_FILE"
    sed -i "s|#updates_interval = '4h'|updates_interval = '4h'|g" "$CONFIG_FILE"
    # if [ "$ENABLE_COMMANDS" -eq 1 ]; then
    sed -i "s/#allow = .*/allow = ['.*']/g" "$CONFIG_FILE"
    sed -i "s/#deny = .*/deny = []/g" "$CONFIG_FILE"
    sed -i '/^\[remote-scripts\]/a \ \ enabled = true' "$CONFIG_FILE"
    sed -i "s|# script_dir = '/var/lib/rport/scripts'|script_dir = '/var/lib/rport/scripts'|g" "$CONFIG_FILE"
    # fi
    # Disable system_id that takes /etc/machine-id as default value
    if grep -Eq "^use_system_id = true" "$CONFIG_FILE"; then
        sed -i "s/^use_system_id = true/use_system_id = false/g" "$CONFIG_FILE"
    fi
    # Set system_id and hostname according to DojoPlateforme's user and workshop
    sed -i "s/#*name = .*/name = \"u${DOJO_USERID}w${DOJO_WORKSHOPID}-$(get_hostname)\"/g" "$CONFIG_FILE"
    sed -i -E "s/^use_hostname = (.*)/use_hostname = false/g" "$CONFIG_FILE"
    sed -i "s/#id = .*/id = \"u${DOJO_USERID}w${DOJO_WORKSHOPID}\"/g" "$CONFIG_FILE"
    systemctl daemon-reload
    systemctl enable rport
}

case $1 in
--conf|-c)
    shift
    while [[ $# -ne 0 ]]; do
        case $1 in
        "--dojo-userid") 
            shift
            export DOJO_USERID=$1
            if grep "DOJO_USERID" "$parent_path/env.sh"; then
                sed -i -E "s/^DOJO_USERID=(.*)/DOJO_USERID=$1/g" "$parent_path/env.sh"
            else
                sed -i '$a\DOJO_USERID='"$1" "$parent_path/env.sh"
            fi
            ;;
        "--dojo-workshopid")
            shift
            export DOJO_WORKSHOPID=$1
            if grep "DOJO_WORKSHOPID" "$parent_path/env.sh"; then
                sed -i -E "s/^DOJO_WORKSHOPID=(.*)/DOJO_WORKSHOPID=$1/g" "$parent_path/env.sh"
            else
                sed -i '$a\DOJO_WORKSHOPID='"$1" "$parent_path/env.sh"
            fi
            ;;
        *)
            shift;;
        esac
    done
    log_info "Starting rport configuration..."
    configure_rport
    enable_lan_monitoring
    detect_interpreters
    ;;
--start)
    log_info "Starting rport service..."
    systemctl start rport
    ;;
--set-vncserver)
    client_id="u${DOJO_USERID}w${DOJO_WORKSHOPID}"
    log_info "Setting VNC server tunnel on rport for client '$client_id'"
    json_data_separator
    curl -k -u admin:shihan -XPUT -H "accept: application/json" "$RPORTD_API_URL/api/v1/clients/$client_id/tunnels?remote=5901&scheme=vnc&acl=172.20.0.1&http_proxy=true&check_port=0"
    ;;
--set-ttyd)
    client_id="u${DOJO_USERID}w${DOJO_WORKSHOPID}"
    log_info "Setting ttyd HTTP tunnel on rport for client '$client_id'"
    json_data_separator
    curl -k -u admin:shihan -XPUT -H "accept: application/json" "$RPORTD_API_URL/api/v1/clients/$client_id/tunnels?remote=7681&scheme=http&acl=172.20.0.1&check_port=0"
    ;;
--help|-h)
    cat <<EOF
configure_rport.sh: Use this script to configure rport client.

Usage: sudo ./configure_rport.sh [OPTIONS] ...

Environment:
    DOJO_USERID [Required]              DojoPlateforme's user id
    DOJO_WORKSHOPID [Required]          DojoPlateforme's workshop id

Options:
    --start                             Start rport client service
    --conf                              Configure rport client config file
    --dojo-userid                       Required by --conf. Override DOJO_USERID
    --dojo-workshopid                   Required by --conf. Override DOJO_WORKSHOPID
    --set-ttyd                          Configure ttyd tunnel on rportd server
    --set-vncserver                     Configure VNC tunnel on rportd server

Options: options are case-sensitive
EOF
    ;;
esac
exit $?
