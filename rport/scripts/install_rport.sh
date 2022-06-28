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

parent_path=$(dirname $(realpath $0))
. $parent_path/env.sh


check_prerequisites() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "Execute as root or use sudo."
        exit 2
    fi

    if command -v sed >/dev/null 2>&1; then
        true
    else
        log_error "sed command missing. Make sure sed is installed and in your path."
        exit 2
    fi

    if command -v tar >/dev/null 2>&1; then
        true
    else
        log_error "tar command missing. Make sure tar is installed and in your path."
        exit 2
    fi

    if command -v curl >/dev/null 2>&1; then
        true
    else
        log_error "curl command missing. Make sure curl is installed and in your path."
        exit 2
    fi
}


install(){
    log_info "Downloading rport client version $RPORT_RELEASE for $(uname).$(uname -m)..."
    curl -LOJ "https://github.com/cloudradar-monitoring/rport/releases/download/${RPORT_RELEASE}/${RPORT_TAR_FILE}"
    log_info "Extracting rport binairy to /usr/local/bin/rport..."
    tar vxzf $RPORT_TAR_FILE -C /usr/local/bin/ rport >> /dev/null
    log_info "Creating rport user and its home directory /var/lib/rport..."
    useradd -d /var/lib/rport -U -m -r -s /bin/false rport
    log_info "Creating required directories with right permissions /etc/rport/ /var/log/rport/..."
    mkdir /etc/rport/
    mkdir /var/log/rport/
    chown rport /var/log/rport/
    log_info "Extracting rport client configuration template /etc/rport/rport.example.conf..."
    tar vxzf $RPORT_TAR_FILE -C /etc/rport/ rport.example.conf >> /dev/null
    log_info "Configuring $CONFIG_FILE from template with our settings..."
    cp /etc/rport/rport.example.conf $CONFIG_FILE
    log_info "Installing rport service"
    rport --service install --service-user rport --config $CONFIG_FILE
    systemctl daemon-reload 
    systemctl disable rport
    rm -f $RPORT_TAR_FILE
    log_info "Installation of rport is complete."
}

check_prerequisites
install

exit 0
