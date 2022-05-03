#!/usr/bin/env bash
set -e
## snippets/shared/01-header.sh -----------|
#======================================================================================================================
# vim: softtabstop=4 shiftwidth=4 expandtab fenc=utf-8 spell spelllang=en cc=120
#======================================================================================================================
#
#          FILE: rportd-installer.sh
#
#   DESCRIPTION: Bootstrap RPortd installation for various distributions
#
#          BUGS: https://github.com/cloudradar-monitoring/rportd-installer/issues
#
#     COPYRIGHT: (c) 2022 by the CloudRadar Team,
#
#       LICENSE: MIT
#  ORGANIZATION: cloudradar GmbH, Potsdam, Germany (cloudradar.io)
#       CREATED: 10/10/2020
#       UPDATED: 08/04/2022
#======================================================================================================================
## END of snippets/shared/01-header.sh -----------|
## snippets/shared/02-prerequisites-check.sh -----------|
if ! uname -o |grep -qi linux ; then
  echo "This installer runs on Linux only."
  exit 1
fi

if [[ $SHELL =~ bash ]] 2>/dev/null;then
    true
else
    2>&1 echo "Execute with bash. Exit."
    exit 1
fi

if id|grep -q uid=0; then
  true
else
  echo "This installer needs to be run with root rights."
  echo "Change to the root account or execute"
  echo "sudo $0 $*"
  false
fi
[ "$TERM" = 'dumb' ]||[ -z "$TERM" ]&&export TERM=xterm-256color
## END of snippets/shared/02-prerequisites-check.sh -----------|
## snippets/shared/03-traps.sh -----------|
on_fail() {
  echo ""
  echo "We are very sorry. Something went wrong."
  echo "Command '$previous_command' exited erroneous on line $1."
  echo "If you need help solving the issue ask for help on"
  echo "https://github.com/cloudradar-monitoring/rportd-installer/discussions/categories/help-needed"
  echo ""
}
debug() {
  previous_command=$this_command
  this_command=$BASH_COMMAND
}
trap 'debug' DEBUG
trap 'on_fail ${LINENO}' ERR

## END of snippets/shared/03-traps.sh -----------|
## snippets/shared/04-functions.sh -----------|
#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  is_terminal
#   DESCRIPTION:  check the scripts is executed on a terminal that allows interactive input
#    PARAMETERS:  ?
#       RETURNS:  exit code 0 un success (aka. is terminal), 1 otherwise
#----------------------------------------------------------------------------------------------------------------------
is_terminal() {
  if echo "$TERM" | grep -q "^xterm" && [ -n "$COLUMNS" ]; then
    return 0
  else
    echo 1>&2 "You are not on an interactive terminal. Please use command line switches to avoid interactive questions."
    return 1
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  progress
#   DESCRIPTION:  Reads a pipe and prints a # for each line received. Pipe is stored to a log file
#    PARAMETERS:  reads pipe
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
progress() {
  if [ -z "$1" ]; then
    echo "function: progress(); Log file missing"
    return 1
  fi
  LOG_FILE=$1
  COUNT=1
  test -e "$LOG_FILE" && rm -f "$LOG_FILE"
  [ -z "$COLUMNS" ] && COLUMNS=120
  while read -r LINE; do
    echo -n "#"
    echo "$LINE" >>"$LOG_FILE"
    if [ $COUNT -eq $COLUMNS ]; then
      echo -e "\r"
      COUNT=0
    fi
    ((COUNT += 1))
  done
  echo ""
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  confirm
#   DESCRIPTION:  Ask interactively for a confirmation
#    PARAMETERS:  Text to ask
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
confirm() {
  if [ -z "$1" ]; then
    echo -n "Do you want to proceed?"
  else
    echo -n "$1"
  fi
  echo " (y/n)"
  while read -r INPUT; do
    if echo "$INPUT" | grep -q "^[Yy]"; then
      return 0
    else
      return 1
    fi
  done
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  ask_for_email
#   DESCRIPTION:  interactively ask for an email and store it to the global EMAIL variable.
#    PARAMETERS:
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
ask_for_email() {
  if ! is_terminal; then
    throw_fatal "use --email <EMAIL> to specify an email for 2fa or select another 2fa method."
  fi
  echo "Please enter your email address:"
  while read -r INPUT; do
    unset EMAIL
    if echo "$INPUT" | grep -q ".*@.*\.[a-z A-Z]"; then
      EMAIL=$INPUT
      if confirm "Is ${EMAIL} your correct email address?"; then
        return 0
      else
        echo "Please enter your email address:"
      fi
    else
      echo "ERROR: This is not a valid email. Try again or abort with CTRL-C"
      echo "Please enter your email address:"
    fi
  done
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  set_email
#   DESCRIPTION:  validate the input for a valid email and store in the global EMAIL variable on success.
#    PARAMETERS:  (string) email
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
set_email() {
  if echo "$1" | grep -q ".*@.*\.[a-z A-Z]"; then
    EMAIL=$1
    throw_info "Your email is \"$EMAIL\""
  else
    throw_fatal "\"$1\" is not a valid email address"
  fi
}

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
  throw_info "Uninstalling the rport server ..."
  ## systemctl stop rportd >/dev/null 2>&1 || true
  rc-service rportd stop >/dev/null 2>&1 || true
  pkill -9 rportd >/dev/null 2>&1 || true
  rport --service uninstall >/dev/null 2>&1 || true
  FILES="/usr/local/bin/rportd
/etc/systemd/system/rportd.service
/etc/init.d/rportd
/usr/local/bin/2fa-sender.sh"
  for FILE in $FILES; do
    if [ -e "$FILE" ]; then
      rm -f "$FILE"
      throw_debug "Deleted file $FILE"
    fi
  done
  if id rport >/dev/null 2>&1; then
    if is_available deluser; then
      deluser rport
    elif is_available userdel; then
      userdel -r -f rport
    fi
    if groups rport >/dev/null 2>&1 && is_available groupdel; then
      groupdel -f rport
    fi
    throw_debug "Deleted user adn group 'rport'"
  fi
  FOLDERS="/etc/rport
/var/log/rport
/var/lib/rport"
  for FOLDER in $FOLDERS; do
    if [ -e "$FOLDER" ]; then
      rm -rf "$FOLDER"
      throw_debug "Deleted folder $FOLDER"
    fi
  done
  uninstall_guacd
  throw_info "RPort Server and it's components uninstalled."
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  uninstall_guacd
#   DESCRIPTION:  Uninstall the guacamole proxy daemon if present
#    PARAMETERS:  ?
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
uninstall_guacd() {
  if ! command -v dpkg >/dev/null; then return; fi
  if ! dpkg -l | grep -q rport-guacamole; then return; fi
  throw_debug "Purging rport-guacamole package"
  apt-get -y remove --purge rport-guacamole
  throw_info "Consider running 'apt-get auto-remove' do clean up your system."
}

# Num  Colour    #define         R G B
#0    black     COLOR_BLACK     0,0,0
#1    red       COLOR_RED       1,0,0
#2    green     COLOR_GREEN     0,1,0
#3    yellow    COLOR_YELLOW    1,1,0
#4    blue      COLOR_BLUE      0,0,1
#5    magenta   COLOR_MAGENTA   1,0,1
#6    cyan      COLOR_CYAN      0,1,1
#7    white     COLOR_WHITE     1,1,1
#tput setab [1-7] # Set the background colour using ANSI escape
#tput setaf [1-7] # Set the foreground colour using ANSI escape
#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  throw_error
#   DESCRIPTION:  prints to stderr of the console
#    PARAMETERS:  text to be printed
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
throw_error() {
  echo 2>&1 "$(tput setab 1)$(tput setaf 7)[!]$(tput sgr 0) $1"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  throw_fatal
#   DESCRIPTION:  prints to stderr of the console
#    PARAMETERS:  text to be printed
#       RETURNS:  false, which usually ends a script run with "-e"
#----------------------------------------------------------------------------------------------------------------------
throw_fatal() {
  echo 2>&1 "[!] $1"
  echo "[=] Fatal Exit. Don't give up. Good luck with the next try."
  false
}

throw_hint() {
  echo "[>] $1"
}

throw_info() {
  echo "$(tput setab 2)$(tput setaf 7)[*]$(tput sgr 0) $1"
}

throw_warning() {
  echo "[:] $1"
}

throw_debug() {
  echo "$(tput setab 4)$(tput setaf 7)[-]$(tput sgr 0) $1"
}

local_ip() {
  IP=$(awk '/32 host/ { print f } {f=$2}' <<<"$(</proc/net/fib_trie)" | grep -E "^(10|192.168|172.16)" | head -n1)
  [ -z "$IP" ] && return 1
  echo "$IP"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  external_ip
#   DESCRIPTION:  get the first external aka public IP Address if system has one
#    PARAMETERS:
#       RETURNS:  (string) IP address
#----------------------------------------------------------------------------------------------------------------------
external_ip() {
  IP=$(awk '/32 host/ { print f } {f=$2}' <<<"$(</proc/net/fib_trie)" | grep -E -v "^(10|192.168|172.16)" | head -n1)
  [ -z "$IP" ] && return 1
  echo "$IP"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  install_guacd
#   DESCRIPTION:  Install the guacamole daemon guacd if the rportd version and the distribution supports it
#    PARAMETERS:  ?
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
install_guacd() {
  if [ -d /opt/rport-guacamole ]; then
    throw_info "Guacamole Proxy for Rport already installed"
    return 1
  fi
  if grep -q '#guacd_address' "$CONFIG_FILE"; then
    true
  else
    # RPortd does not support guacamole proxy
    return 1
  fi
  if [ "$INSTALL_GUACD" -eq 0 ]; then
    throw_info "Skipping Guacamole Proxy installation."
    return 1
  fi

  if grep -q "^ID.*=debian$" /etc/os-release; then
    throw_info "Going to install the Guacamole Proxy Daemon for RPort using Debian/Ubuntu Packages"
  else
    throw_info "No packages for the Guacamole Proxy Daemon available for your OS. Skipping."
    return 1
  fi
  # shellcheck source=/dev/null
  . /etc/os-release
  GUACD_PKG=rport-guacamole_1.4.0_${ID}_${VERSION_CODENAME}_$(uname -m).deb
  GUACD_DOWNLOAD=https://bitbucket.org/cloudradar/rport-guacamole/downloads/${GUACD_PKG}
  throw_debug "Downloading $GUACD_PKG"
  cd /tmp
  curl -fLOSs "$GUACD_DOWNLOAD" || (throw_error "Download failed" && return 0)
  throw_debug "Installing ${GUACD_PKG} via apt-get"
  DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install ./"${GUACD_PKG}" | progress /tmp/guacd-install.log
  rm -f ./"${GUACD_PKG}"
  if grep -q "^E:" /tmp/guacd-install.log; then
    throw_error "Installation of guacd failed. See /tmp/guacd-install.log"
  else
    rm -f /tmp/guacd-install.log
  fi
  sleep 1
  if pgrep -c guacd >/dev/null; then
    throw_info "Guacamole Proxy Daemon for RPort installed."
    return 0
  else
    throw_error "Installation of Guacamole Proxy Daemon for RPort failed."
    return 1
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  activate_guacd
#   DESCRIPTION:  Activate the guacd in the rportd.conf
#    PARAMETERS:
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
activate_guacd() {
  if grep -q -E "\sguacd_address =" "$CONFIG_FILE"; then
    throw_info "Guacamole Proxy Daemon already registered in ${CONFIG_FILE}"
    return 0
  fi
  sed -i "s|#guacd_address =.*|guacd_address = \"127.0.0.1:9445\"|g" "$CONFIG_FILE"
  ## systemctl restart rportd
  throw_debug "Guacamole Proxy Daemon registered in ${CONFIG_FILE}"
  echo "What's next"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  install_novnc
#   DESCRIPTION:  Install the NoVNC Javasript files by downloading from the github repo
#    PARAMETERS:  ?
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
install_novnc() {
  if [ -d /var/lib/rport/noVNC-1.3.0 ]; then
    throw_info "NoVNC already installed"
    return 0
  fi
  if [ -n "$NOVNC_ROOT" ]; then
    NOVNC_DOWNLOAD='https://github.com/novnc/noVNC/archive/refs/tags/v1.3.0.zip'
    throw_debug "Downloading $NOVNC_DOWNLOAD"
    curl -LSs $NOVNC_DOWNLOAD -o /tmp/novnc.zip
    unzip -o -qq -d /var/lib/rport /tmp/novnc.zip
    rm -f /tmp/novnc.zip
    chown -R rport:rport "$NOVNC_ROOT"
    throw_info "NoVNC Addon installed to $NOVNC_ROOT"
  fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  activate_novnc
#   DESCRIPTION:  Make all changes to rportd.conf to activate NoVNC
#    PARAMETERS:  ?
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
activate_novnc() {
  if grep -q -E "\snovnc_root =" "$CONFIG_FILE"; then
    throw_info "NoVNC already registered in ${CONFIG_FILE}"
    return 0
  fi
  NOVNC_ROOT='/var/lib/rport/noVNC-1.3.0'
  sed -i "s|#novnc_root =.*|novnc_root = \"${NOVNC_ROOT}\"|g" "$CONFIG_FILE"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  version_to_int
#   DESCRIPTION:  convert a semver version string to integer to be comparable mathematically
#    PARAMETERS:  semver string
#       RETURNS:  integer
#----------------------------------------------------------------------------------------------------------------------
version_to_int() {
  echo "$1" |
    awk -v 'maxsections=3' -F'.' 'NF < maxsections {printf("%s",$0);for(i=NF;i<maxsections;i++)printf("%s",".0");printf("\n")} NF >= maxsections {print}' |
    awk -v 'maxdigits=3' -F'.' '{print $1*10^(maxdigits*2)+$2*10^(maxdigits)+$3}'
}

## END of snippets/shared/04-functions.sh -----------|
## snippets/installer/01-functions.sh -----------|
#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  fqdn_is_public
#   DESCRIPTION:  Check if a FQDN is publicly resolvable through the cloudflare DNS over HTTP
#                 see https://developers.cloudflare.com/1.1.1.1/encryption/dns-over-https/
#    PARAMETERS:  FQDN
#       RETURNS:  exit code 0 if query resolves, 1 otherwise
#----------------------------------------------------------------------------------------------------------------------
fqdn_is_public() {
  if curl -fs -H 'accept: application/dns-json' "https://cloudflare-dns.com/dns-query?name=${1}" | grep -q '"Status":0'; then
    return 0
  else
    return 1
  fi
}

set_fqdn() {
  FQDN=$(echo "$1"| tr '[:upper:]' '[:lower:]')
  PUBLIC_FQDN=0
  if fqdn_is_public "${FQDN}"; then
    PUBLIC_FQDN=1
  else
    throw_info "FQDN ${FQDN} seems to be privat or local."
  fi
}

is_cloud_vm() {
  if [ -e /etc/cloud/digitalocean.info ]; then
    throw_debug "Installing on DigitalOcean"
    return 0
  fi

  if [ -e /etc/cloud-release ] && grep -q azure /etc/cloud-release; then
    throw_debug "Installing on Microsoft Azure"
    return 0
  fi

  if [ -e /etc/default/grub ] && grep -q vultr /etc/default/grub; then
    throw_debug "Installing on Vultr"
    return 0
  fi

  if [ -e /etc/cloud-release ] && grep -q ec2 /etc/cloud-release; then
    throw_debug "Installing on AWS EC2"
    return 0
  fi

  if [ -e /etc/boto.cfg ] && grep -q GoogleCompute /etc/boto.cfg; then
    throw_debug "Installing on Google GCE"
    return 0
  fi

  if [ -e /etc/scw-kernel-check.conf ] && grep -q Scaleway /etc/scw-kernel-check.conf; then
    throw_debug "Installing on Scaleway"
    return 0
  fi

  if [ -e /etc/cloud/cloud.cfg.d/90_dpkg.cfg ] && grep -q Hetzner /etc/cloud/cloud.cfg.d/90_dpkg.cfg; then
    throw_debug "Installing on Hetzner Cloud"
    return 0
  fi

  if command -v dmidecode >/dev/null 2>&1; then
    BIOS_VENDOR=$(dmidecode -s bios-vendor)
  else
    return 1
  fi
  case $BIOS_VENDOR in
  DigitalOcean)
    throw_debug "Installing on DigitalOcean"
    return 0
    ;;
  Hetzner)
    throw_debug "Installing on Hetzner"
    return 0
    ;;
  esac
  return 1
}

get_public_ip() {
  if [ -z "$MY_IP" ]; then
    MY_IP=$(curl -s 'https://api.ipify.org?format=text')
    if [ -z "$MY_IP" ]; then
      throw_error "Determining your public IP address failed."
      throw_hint "Make sure https://api.ipify.org is not blocked"
      false
    fi
    throw_debug "Your public IP address ${MY_IP}."
  fi
}

is_behind_nat() {
  if [ "$USES_NAT" -eq 0 ]; then
    # Skip the check if user has negated NAT explicitly.
    throw_debug "NAT check disabled."
    return 1
  fi

  if is_cloud_vm; then
    # Skip the check on well-known cloud providers.
    return 1
  fi
  get_public_ip
  if ip a | grep -q "$MY_IP"; then
    throw_info "Public IP address directly bound to the system."
    USES_NAT=0
    return 1
  else
    throw_info "System uses NAT"
    USES_NAT=1
    return 0
  fi
}

rejects_pings() {
  get_public_ip
  if ping -c1 -W2 -q "$MY_IP" >/dev/null 2>&1; then
    return 1
  else
    return 0
  fi
}

is_free_port() {
  TEST=$(nc -z -w 1 127.0.0.1 "$1" -v 2>&1)
  if echo "$TEST" | grep -q "connect to 127.0.0.1.*Connection refused"; then
    return 0
  elif echo "$TEST" | grep -q succeeded; then
    throw_error "Port $1 is in use."
    return 1
  elif [ "$1" -lt 65536 ]; then
    if timeout 5 bash -c "</dev/tcp/127.0.0.1/${1}" &>/dev/null; then
      throw_error "Port $1 is in use."
      return 1
    else
      return 0
    fi
  else
    throw_error "$1 is not valid TCP port."
    false
  fi
}

set_api_port() {
  throw_info "Setting API_PORT to $1"
  if is_free_port "$1"; then
    API_PORT=$1
  else
    throw_fatal "Setting API_PORT to $1 failed."
  fi
}

set_client_port() {
  throw_info "Setting CLIENT_PORT to $1"
  if is_free_port "$1"; then
    CLIENT_PORT="$1"
  else
    throw_error "Setting CLIENT_PORT failed."
    exit 1
  fi
}

set_tunnel_port_range() {
  if echo "$1" | grep -q -E "^[0-9]+\-[0-9]+$"; then
    throw_debug "Using tunnel port range $1"
    TUNNEL_PORT_RANGE=$1
  else
    throw_fatal "Invalid port range $1. Specify two integers separated by a dash. Example '10000-100100'."
  fi
}

set_client_url() {
  if echo "$1" | grep -E -q "^https?:\/\/[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$"; then
    throw_debug "Setting client connect URL $1"
    CLIENT_URL=$1
    if LANG=en curl -m4 -vsSI "${CLIENT_URL}" 2>&1 | grep -q "Could not resolve host"; then
      throw_fatal "Could not resolve host of ${CLIENT_URL}. Register the hostname on your DNS first."
    fi
  else
    throw_fatal "$1 is not valid URL of scheme http(s)://<HOST>(:<PORT>)"
  fi
}

## END of snippets/installer/01-functions.sh -----------|
## snippets/installer/01-vars.sh -----------|
# GLOBAL VARS
export LANG=C.UTF-8
export PAGER=cat



## END of snippets/installer/01-vars.sh -----------|
## snippets/installer/02-launch.sh -----------|
help() {
  cat <<EOF
Usage $0 [OPTION(s)]

Options:
-h,--help  Print this help message
-f,--force  Force, overwriting existing files and configurations
-t,--unstable  Use the latest unstable version (DANGEROUS!)
-e,--email {EMAIL}  Don't ask for the email interactively
-d,--fqdn {FQDN}  Use a custom FQDN. Otherwise a random FQDN on *.users.rport.io will be created.
-k,--skip-dnscheck Do not verify {FQDN} exists. Install anyway.
-u,--uninstall  Uninstall rportd and all related files
-c,--client-port {PORT} Use a different port than 80 for the client aka agent connections.
-i,--client-url {URL} Instruct clients to connect to this URL instead of {FQDN}
-a,--api-port {PORT} Use a different port than 443 for the API and the Web UI.
-s,--skip-nat Do not detect NAT and assume direct internet connection with public IP address (e.g. one-to-one NAT).
-o,--totp Use time-based one time passwords (TOTP) instead of email for two-factor authentication
-n,--no-2fa Disable two factor authentification
-p,--port-range ports dynamically used for active tunnels. Default 20000-30000
-g,--skip-guacd Do not install a version of the Guacamole Proxy Daemon needed for RDP over web.

Examples:
sudo bash $0 --email user@example.com
  Installs the RPort server with a randomly generated FQDN <RAND>.users.rport.io
  used for client connect, the API and the Web UI. Email-based two-factor authentication is enabled.

sudo bash $0 --no-2fa \\
  --fqdn rport.local.localnet \\
  --api-port 8443 \\
  --port-range 5000-5050 \\
  --client-url http://my-rport-server.dyndns.org:8080
  Installs the RPort server
    * with a fixed local FQDN.
    * Port 8443 is used for the user interface and the API.
    * Clients are expected outside the local network connecting over a port forwarding via a public FQDN.
    * No two factor authentication is used. (not recommended)
    * Self-signed certificates are generated because Let's encrypt denies using port 8443 for identity validation.
EOF
}

#
# Read the command line options and map to a function call
#
TEMP=$(getopt \
  -o vhta:sone:d:c:d:p:i:ug \
  --long version,help,unstable,fqdn:,email:,client-port:,api-port:,port-range:,client-url:,uninstall,skip-nat,skip-guacd,totp,no-2fa \
  -- "$@")
eval set -- "$TEMP"

RELEASE=stable
API_PORT=443
CLIENT_PORT=80
DB_FILE=/var/lib/rport/user-auth.db
DNS_CREATED=0
USES_NAT=2
TUNNEL_PORT_RANGE='20000-30000'
TWO_FA=email
INSTALL_GUACD=1
VERSION="2204.26.1006"

# extract options and their arguments into variables.
while true; do
  case "$1" in
  -h | --help)
    help
    exit 0
    ;;
  -t | --unstable)
    RELEASE=unstable
    shift 1
    ;;
  -d | --fqdn)
    set_fqdn "$2"
    shift 2
    ;;
  -e | --email)
    set_email "$2"
    shift 2
    ;;
  -u | --uninstall)
    uninstall
    exit 0
    ;;
  -c | --client-port)
    set_client_port "$2"
    shift 2
    ;;
  -i | --client-url)
    set_client_url "$2"
    shift 2
    ;;
  -a | --api-port)
    set_api_port "$2"
    shift 2
    ;;
  -s | --skip-nat)
    USES_NAT=0
    shift 1
    ;;
  -o | --totp)
    TWO_FA=totp
    EMAIL=user@example.com
    shift 1
    ;;
  -n | --no-2fa)
    TWO_FA=none
    shift 1
    ;;
  -p | --port-range)
    set_tunnel_port_range "$2"
    shift 2
    ;;
  -g | --skip-guacd)
    INSTALL_GUACD=0
    shift 1
    ;;
  -v | --version)
    echo "Version $VERSION"
    exit 0
    ;;
  --)
    shift
    break
    ;;
  *)
    echo "Internal error!"
    help
    exit 1
    ;;
  esac
done

if [ -e /etc/os-release ] && grep -q 'REDHAT_SUPPORT_PRODUCT_VERSION="7"' /etc/os-release; then
  throw_fatal "Sorry. RedHat/CentOS/Alma/Rocky Linux >=8 required."
fi

if [ -e /etc/os-release ] && grep -q '^REDHAT_SUPPORT_PRODUCT_VERSION=".*Stream"$' /etc/os-release; then
  throw_fatal "Sorry. CentOS Stream not supported yet."
fi

if [ -e /etc/os-release ] && grep -q "^ID_LIKE.*rhel" /etc/os-release; then
  if rpm -qa | grep -q epel-release; then
    true
  else
    throw_fatal "Please enable the epel-release and try again. Try 'dnf install epel-release'."
  fi
fi

if [ -z "$FQDN" ]; then
  if is_behind_nat; then
    # If machine is behind NAT we do not create a random FQDN, because the IP is very likely a dynamic one.
    throw_error "Random FQDNs are only generated for systems with a public IP address."
    throw_hint "If this system is behind a one-to-one NAT (Azure, AWS EC2, Scaleway, GPE) use '--skip-nat'"
    throw_hint "If your are behind a NAT with a dynamic IP address provide a FQDN with '--fqdn'"
    throw_fatal "NAT detected"
  fi

  if rejects_pings; then
    throw_hint "Check your firewall settings and allow incoming ICMP v4."
    throw_fatal "Pings denied. System does not respond to ICMP echo requests aka pings on the public IP address."
  fi
fi

if [ -z $EMAIL ] && [ $TWO_FA != 'none' ]; then
  bold=$(tput bold)
  normal=$(tput sgr0)
  echo ""
  echo " | RPort comes with two factor authentication enabled by default."
  echo " | To send the first 2fa-token a ${bold}valid email address is needed${normal}."
  echo " | Your email address will be stored only locally on this system inside the user database."
  ask_for_email
fi

## END of snippets/installer/02-launch.sh -----------|
## snippets/installer/03-install-dependencies.sh -----------|
#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  install_dependencies
#   DESCRIPTION:  For the installation we need some tools, let's install them quickly..
#    PARAMETERS:
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
install_dependencies() {
  DEP_INSTALL_LOG="/tmp/rportd-install-dependencies.log"
  echo "$(date) -- installing rportd dependencies" >$DEP_INSTALL_LOG
  RPM_DEPS=(unzip sqlite nmap-ncat httpd-tools tar)
  DEB_DEPS=(pwgen apache2-utils unzip curl sqlite3 netcat)
  if [ "$API_PORT" -eq 443 ]; then
    DEB_DEPS+=(certbot)
    RPM_DEPS+=(certbot)
  fi
  throw_info "Installing Dependencies ... be patient."
  if is_available apt-get; then
    throw_debug "The following packages will be installed: ${DEB_DEPS[*]}"
    apt-get -y update
    DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install "${DEB_DEPS[@]}"  2>&1| progress $DEP_INSTALL_LOG
  elif is_available dnf; then
    throw_debug "Installing dependencies using dfn."
    throw_debug "The following packages will be installed: ${RPM_DEPS[*]}"
    dnf -y install "${RPM_DEPS[@]}"
  elif is_available yum; then
    throw_debug "Installing dependencies using yum."
    throw_debug "The following packages will be installed: ${RPM_DEPS[*]}"
    yum -y install "${RPM_DEPS[@]}"
  else
    throw_fatal "No supported package manager found. 'apt-get', 'dfn' or 'yum' required."
  fi
  if grep -q "^E:" $DEP_INSTALL_LOG; then
    throw_fatal "Installing dependencies failed. See $DEP_INSTALL_LOG"
  else
    #rm -f "$DEP_INSTALL_LOG"
    throw_info "Dependencies installed."
  fi
}
install_dependencies
## Prepare the UFW firewall if present
if command -v ufw >/dev/null 2>&1; then
  throw_info "UFW firewall detected. Adding rules now."
  throw_debug "Allowing API Port ${API_PORT}"
  ufw allow "${API_PORT}"/tcp
  throw_debug "Allowing Client Port ${CLIENT_PORT}"
  ufw allow "${CLIENT_PORT}"/tcp
  throw_debug "Allowing Tunnel Port Range ${TUNNEL_PORT_RANGE}"
  ufw allow "$(echo "${TUNNEL_PORT_RANGE}" | tr - :)"/tcp
fi

## END of snippets/installer/03-install-dependencies.sh -----------|
## snippets/installer/04-install-server.sh -----------|
# Install the RPort Server
ARCH=$(uname -m | sed s/aarch64/arm64/)
DOWNLOAD_URL="https://download.rport.io/rportd/${RELEASE}/latest.php?arch=${ARCH}"
throw_debug "Downloading ${DOWNLOAD_URL}"
curl -LSs "${DOWNLOAD_URL}" -o rportd.tar.gz
tar vxzf rportd.tar.gz -C /usr/local/bin/ rportd
id rport >/dev/null 2>&1||useradd -d /var/lib/rport -m -U -r -s /bin/false rport
test -e /etc/rport||mkdir /etc/rport/
test -e /var/log/rport||mkdir /var/log/rport/
chown rport /var/log/rport/
tar vxzf rportd.tar.gz -C /etc/rport/ rportd.example.conf
cp /etc/rport/rportd.example.conf /etc/rport/rportd.conf

# Create a unique key for your instance
KEY_SEED=$(openssl rand -hex 18)
sed -i "s/key_seed = .*/key_seed =\"${KEY_SEED}\"/g" /etc/rport/rportd.conf

# Create a systemd service
## /usr/local/bin/rportd --service install --service-user rport --config /etc/rport/rportd.conf||true
## sed -i '/^\[Service\]/a LimitNOFILE=1048576' /etc/systemd/system/rportd.service
## sed -i '/^\[Service\]/a LimitNPROC=512' /etc/systemd/system/rportd.service
## systemctl daemon-reload
#systemctl start rportd
## systemctl enable rportd
if /usr/local/bin/rportd --version;then
  true
else
  throw_fatal "Unable to start the rport server. Check /var/log/rport/rportd.log"
fi
rm rportd.tar.gz
echo "------------------------------------------------------------------------------"
throw_info "The RPort server has been installed from the latest ${RELEASE} release. "
echo ""

## END of snippets/installer/04-install-server.sh -----------|
## snippets/installer/05-create-dns-record.sh -----------|
#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  wait_for_dns_ready
#   DESCRIPTION:  check the DNS in a loop until the new records becomes available.
#    PARAMETERS:  ?
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
wait_for_dns_ready() {
  throw_info "Waiting for DNS to become ready ... be patient "
  echo -n " "
  for i in $(seq 15); do
    echo -n ". "
    sleep 1
  done
  for i in $(seq 30); do
    if fqdn_is_public "${FQDN}"; then
      throw_info "DNS entry has become available. "
      DNS_READY=1
      break
    else
      DNS_READY=0
      echo -n ". "
      sleep 1
    fi
  done
  if [ $DNS_READY -eq 0 ]; then
    throw_error "Your hostname $FQDN has not become available on the DNS."
    throw_hint "Go to https://rport.io/en/contact and ask for help."
    throw_fatal "Creating an FQDN for your RPort server failed. "
  fi
  throw_info "Waiting for DNS records being propagated ... be patient"
  echo -n " "
  for i in $(seq 10); do
    echo -n ". "
    sleep 1
  done
  echo ""
}

if [ -z "$FQDN" ]; then
  # Create a random DNS record if no FQDN is specified using the free dns service of RPort
  FQDN=$(curl -Ss https://freedns.rport.io -F create=random)
  DNS_CREATED=1
  PUBLIC_FQDN=1
  throw_info "Creating random FQDN on Freedns *.users.rport.io."
  wait_for_dns_ready
elif [[ $FQDN =~ (.*)\.users\.rport\.io$ ]]; then
  # Register a custom DNS record if no FQDN is specified using the free dns service of RPort
  # Requires an authorization token
  FQDN=$(curl -Ss https://freedns.rport.io -F create="${BASH_REMATCH[1]}" -F token="$DNSTOKEN")
  DNS_CREATED=1
  throw_info "Creating custom FQDN ${BASH_REMATCH[1]}.users.rport.io."
  wait_for_dns_ready
fi

if [ $DNS_CREATED -eq 1 ] && echo "$FQDN" | grep -i error; then
  throw_fatal "Creating DNS record failed"
  false
fi

throw_info "Name of your RPort server: $FQDN You can change it later."

## END of snippets/installer/05-create-dns-record.sh -----------|
## snippets/installer/05-create-ssl-certificates.sh -----------|
#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  create_selfsigned_cert
#   DESCRIPTION:  Create a CA and a self signed certificate for $FQDN
#    PARAMETERS:
#       RETURNS:
#----------------------------------------------------------------------------------------------------------------------
create_selfsigned_cert() {
  throw_info "Creating self-signed certificate for $FQDN"
  mkdir -p /etc/rport/ssl/ca/export
  SSL_KEY_FILE=/etc/rport/ssl/${FQDN}_privkey.pem
  SSL_CERT_FILE=/etc/rport/ssl/${FQDN}_certificate.pem
  SSL_CSR_FILE=/etc/rport/ssl/${FQDN}.csr
  SSL_EXT_FILE=/etc/rport/ssl/${FQDN}.ext
  ################## Create a CA #############################################
  # Generate private key
  CA_NAME=${FQDN}
  CA_CERT=/etc/rport/ssl/ca/export/${CA_NAME}-ca-root-cert.crt
  CA_KEY=/etc/rport/ssl/${CA_NAME}-ca.key
  openssl genrsa -out "${CA_KEY}" 2048
  # Generate root certificate
  openssl req -x509 -new -nodes -key "${CA_KEY}" -sha256 -days 825 -out "${CA_CERT}" \
    -subj "/C=GB/ST=London/L=London/O=Global Security/OU=IT Department/CN=${CA_NAME}.local"

  if [ -e "${CA_CERT}" ]; then
    throw_debug "Certificate Authority created in ${CA_CERT}. Import this file into OS and/or browser."
    throw_info "Read https://kb.rport.io/ carefully."
  else
    throw_fatal "Creating Certificate Authority failed."
    false
  fi
  ln -sf "$CA_CERT" /etc/rport/ssl/ca/export/rport-ca.crt
  sleep 0.1

  ########################## Create a CA-signed cert  ##########################
  # Generate a private key
  openssl genrsa -out "${SSL_KEY_FILE}" 2048
  # Create a certificate-signing request
  openssl req -new -key "${SSL_KEY_FILE}" -out "${SSL_CSR_FILE}" \
    -subj "/C=GB/ST=London/L=London/O=Global Security/OU=IT Department/CN=${FQDN}"
  # Create a config file for the extensions
  cat >"${SSL_EXT_FILE}" <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${FQDN}      # Be sure to include the domain name here because Common Name is not so commonly honoured by itself
DNS.2 = $(hostname)  # Be sure to include the domain name here because Common Name is not so commonly honoured by itself
IP.1 = $(local_ip || external_ip) # Optionally, add an IP address (if the connection which you have planned requires it)
EOF
  # Create the signed certificate
  openssl x509 -req -in "${SSL_CSR_FILE}" -CA "${CA_CERT}" -CAkey "${CA_KEY}" -CAcreateserial \
    -out "${SSL_CERT_FILE}" -days 825 -sha256 -extfile "${SSL_EXT_FILE}"
  echo ""
  throw_debug "SSL key and self-signed certificate created."
  chown rport:root "$SSL_KEY_FILE"
  chown rport:root "$SSL_CERT_FILE"
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  create_letsencrypt_cert
#   DESCRIPTION:  Request a Let's encrypt certificate for $FQDN
#    PARAMETERS:
#       RETURNS:  exitcode 1|0
#----------------------------------------------------------------------------------------------------------------------
create_letsencrypt_cert() {
  for i in $(seq 3); do
    throw_debug "Trying to request a Let's encrypt certificate [try $i]"
    if certbot certonly -d "${FQDN}" -n --agree-tos --standalone --register-unsafely-without-email; then
      CERTS_READY=1
      break
    else
      CERTS_READY=0
      sleep 5
    fi
  done
  if [ $CERTS_READY -eq 0 ]; then
    echo "------------------------------------------------------------------------------"
    throw_error "Creating Let's encrypt certificates for your RPort server failed."
    return 1
  fi
  # Change group ownerships so rport can read the files
  CERT_ARCH_DIR=$(find /etc/letsencrypt/archive/ -type d -iname "${FQDN}*")
  CERT_LIVE_DIR=$(find /etc/letsencrypt/live/ -type d -iname "${FQDN}*")
  chgrp rport /etc/letsencrypt/archive/
  chmod g+rx /etc/letsencrypt/archive/
  chgrp rport /etc/letsencrypt/live/
  chmod g+rx /etc/letsencrypt/live/
  chgrp rport "${CERT_ARCH_DIR}"
  chmod g+rx "${CERT_ARCH_DIR}"
  chgrp rport "${CERT_ARCH_DIR}"/privkey1.pem
  chmod g+rx "${CERT_ARCH_DIR}"/privkey1.pem
  chgrp rport "${CERT_LIVE_DIR}"
  SSL_KEY_FILE="${CERT_LIVE_DIR}"/privkey.pem
  SSL_CERT_FILE="${CERT_LIVE_DIR}"/fullchain.pem
  HOOK_FILE=/etc/letsencrypt/renewal-hooks/deploy/restart-rportd
  echo '#!/bin/sh
test -e /usr/bin/logger && /usr/bin/logger -t certbot "Restarting rportd after certificate renewal"' >$HOOK_FILE
#   echo '#!/bin/sh
# test -e /usr/bin/logger && /usr/bin/logger -t certbot "Restarting rportd after certificate renewal"
# /usr/bin/systemctl restart rportd' >$HOOK_FILE
  chmod 0700 $HOOK_FILE
  throw_info "Certificates have been created for your instance "
}

if [ "$API_PORT" -ne 443 ]; then
  throw_info "Skipping Let's encrypt because ACME does not support none default ports."
  create_selfsigned_cert
elif [ "$PUBLIC_FQDN" -ne 1 ]; then
  throw_info "Skipping Let's encrypt because ACME supports only publicly resolvable hostnames."
  create_selfsigned_cert
else
  if create_letsencrypt_cert; then
    true
  else
    throw_info "Falling back to self-signed certificates"
    create_selfsigned_cert
  fi
fi

## END of snippets/installer/05-create-ssl-certificates.sh -----------|
## snippets/installer/06-create-config.sh -----------|
## systemctl stop rportd
CONFIG_FILE='/etc/rport/rportd.conf'
#
# Change the default config.
#
if [ -z "$CLIENT_URL" ];then
  CLIENT_URL=http://${FQDN}:${CLIENT_PORT}
fi
sed -i "s/#address = .*/address = \"0.0.0.0:${CLIENT_PORT}\"/g" $CONFIG_FILE
# Set the url(s) where client can connect to
if grep -q "Optionally defines full client connect URL(s)." $CONFIG_FILE;then
  # New style, set a list
  sed -i "s|#url = .*|url = [\"${CLIENT_URL}\"]|g" $CONFIG_FILE
else
  # Old style, single value
  sed -i "s|#url = .*|url = \"${CLIENT_URL}\"|g" $CONFIG_FILE
fi

sed -i "s/auth = \"clientAuth/#auth = \"clientAuth\"/g" $CONFIG_FILE
sed -i "s|#auth_file.*client-auth.json|auth_file = \"/var/lib/rport/client-auth.json|g" $CONFIG_FILE
sed -i "s/address = \"0.0.0.0:3000\"/address = \"0.0.0.0:${API_PORT}\"/g" $CONFIG_FILE
sed -i "s/auth = \"admin:foobaz\"/#auth = \"admin:foobaz\"/g" $CONFIG_FILE
sed -i "s/#auth_user_table/auth_user_table/g" $CONFIG_FILE
sed -i "s/#auth_group_table/auth_group_table/g" $CONFIG_FILE
sed -i "s/#db_type = \"sqlite\"/db_type = \"sqlite\"/g" $CONFIG_FILE
sed -i "s|#db_name = \"/var.*|db_name = \"$DB_FILE\"|g" $CONFIG_FILE
sed -i "s|#used_ports = .*|used_ports = ['${TUNNEL_PORT_RANGE}']|g" $CONFIG_FILE
sed -i "s/jwt_secret =.*/jwt_secret = \"$(pwgen 18 1 2>/dev/null||openssl rand -hex 9)\"/g" $CONFIG_FILE
# Enable SSL with the previously generated cert and key
sed -i "s|#cert_file =.*|cert_file = \"${SSL_CERT_FILE}\"|g" $CONFIG_FILE
sed -i "s|#key_file =.*|key_file = \"${SSL_KEY_FILE}\"|g" $CONFIG_FILE
# Enable the built-in tunnel proxy
sed -i "s|#tunnel_proxy_cert_file =.*|tunnel_proxy_cert_file = \"${SSL_CERT_FILE}\"|g" $CONFIG_FILE
sed -i "s|#tunnel_proxy_key_file =.*|tunnel_proxy_key_file = \"${SSL_KEY_FILE}\"|g" $CONFIG_FILE
sed -i "s/#doc_root/doc_root/g" $CONFIG_FILE
sed -i "s/totp_account_name = .*/totp_account_name = \"${FQDN}\"/g" $CONFIG_FILE
# Set longer retention period for disconnected clients
sed -i "s/#keep_lost_clients = .*/keep_lost_clients = \"168h\"/g" $CONFIG_FILE
# Set a shorter retention period for monitoring data
sed -i "s/#data_storage_days = .*/data_storage_days = 7/g" $CONFIG_FILE
#sed -i "s/#max_request_bytes/max_request_bytes = 10240/g" $CONFIG_FILE
# Activate the NoVNC proxy
##novnc_root = "/var/lib/rport/novncroot"
if grep -q novnc_root $CONFIG_FILE; then
  activate_novnc
fi
throw_debug "Configuration file $CONFIG_FILE written. "
sleep 0.3
[ -n "${ADMIN_PASSWD}" ] || ADMIN_PASSWD=$(pwgen 9 1 2>/dev/null||openssl rand -hex 5)
PASSWD_HASH=$(htpasswd -nbB password "$ADMIN_PASSWD"|cut -d: -f2)
## Create the database and the first user
test -e "$DB_FILE"&& rm -f "$DB_FILE"
touch "$DB_FILE"
chown rport:rport "$DB_FILE"
cat <<EOF|sqlite3 "$DB_FILE"
CREATE TABLE "users" (
  "username" TEXT(150) NOT NULL,
  "password" TEXT(255) NOT NULL,
  "token" TEXT(36) DEFAULT NULL,
  "two_fa_send_to" TEXT(150),
  "totp_secret" TEXT DEFAULT ""
);
CREATE UNIQUE INDEX "main"."username" ON "users" (
  "username" ASC
);
CREATE TABLE "groups" (
  "username" TEXT(150) NOT NULL,
  "group" TEXT(150) NOT NULL
);
CREATE UNIQUE INDEX "main"."username_group"
ON "groups" (
  "username" ASC,
  "group" ASC
);
INSERT INTO users VALUES('admin','$PASSWD_HASH',null,'$EMAIL','');
INSERT INTO groups VALUES('admin','Administrators');
EOF
throw_debug "RPort Database $DB_FILE created."
sleep 0.3
CLIENT_PASSWD=$(pwgen 18 1 2>/dev/null||openssl rand -hex 9)
## Create the first client credentials
cat > /var/lib/rport/client-auth.json <<EOF
{
    "client1": "$CLIENT_PASSWD"
}
EOF
chown rport:rport /var/lib/rport/client-auth.json
throw_debug "Client auth file /var/lib/rport/client-auth.json written."
sleep 0.3
setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/rportd
# systemctl start rportd
# if [ -z "$(pgrep rportd)" ]; then
#   echo "------------------------------------------------------------------------------"
#   throw_error "Starting your RPort server failed."
#   echo "      Go to https://rport.io/en/contact and ask for help."
#   echo "      The following information might help."
#   tail -n100 /var/log/rport/rportd.log
#   su - rport -s /bin/bash -c "rportd -c $CONFIG_FILE"
#   false
# fi
sleep 3

## END of snippets/installer/06-create-config.sh -----------|
## snippets/installer/07-enable-2fa.sh -----------|
enable_email_2fa() {
  cat << 'EOF' >/usr/local/bin/2fa-sender.sh
#!/bin/bash
#
# This is a script for sending two factor auth token via a free API provided by cloudradar GmbH
# Check https://kb.rport.io/install-the-rport-server/enable-two-factor-authentication
# and learn how to use your own SMTP server or alternative delivery methods
#

# Source a configuration if available
CONF="/etc/rport/2fa-sender.conf"
[ -e "$CONF" ] && . $CONF

log() {
  [ -z "$LOG_LEVEL" ] && return 0
  [ -z "$LOG_FILE" ] && LOG_FILE="/var/log/rport/2fa-sender.log"
  LOG_LINE=("$(date) -- Token sent to ${RPORT_2FA_SENDTO}; ")
  if [ $LOG_LEVEL = 'debug' ];then
    LOG_LINE+=("TOKEN=${RPORT_2FA_TOKEN}; ")
  fi
  LOG_LINE+=("Response: $1")
  echo ${LOG_LINE[*]}>>"$LOG_FILE"
}


# Trigger sending the email via a public API
RESPONSE=$(curl -Ss https://free-2fa-sender.rport.io \
 -F email=${RPORT_2FA_SENDTO} \
 -F token=${RPORT_2FA_TOKEN} \
 -F ttl=${RPORT_2FA_TOKEN_TTL} \
 -F url="_URL_" 2>&1)
if echo $RESPONSE|grep -q "Message sent";then
    echo "Token sent via email"
    log "Message sent"
    exit 0
else
    >&2 echo $RESPONSE
    log "Error \"$RESPONSE\""
    exit 1
fi
EOF
  sed -i "s|_URL_|https://${FQDN}:${API_PORT}|g" /usr/local/bin/2fa-sender.sh
  chmod +x /usr/local/bin/2fa-sender.sh
  sed -i "s|#two_fa_token_delivery.*|two_fa_token_delivery = \"/usr/local/bin/2fa-sender.sh\"|g" /etc/rport/rportd.conf
  sed -i "s|#two_fa_send_to_type.*|two_fa_send_to_type = \"email\"|g" /etc/rport/rportd.conf
  TWO_FA_MSG="After the log in, check the inbox of ${EMAIL} to get the two-factor token."
  systemctl restart rportd
  throw_info "${TWO_FA}-based two factor authentication installed."
}

enable_totp_2fa() {
  sed -i "s|#totp_enabled.*|totp_enabled = true|g" /etc/rport/rportd.conf
  sed -i "s|#totp_login_session_ttl|totp_login_session_ttl|g" /etc/rport/rportd.conf
  TWO_FA_MSG="After the log in, you must set up your TOTP authenticator app."
  systemctl restart rportd
  throw_info "${TWO_FA}-based two factor authentication installed."
}

if [ "$TWO_FA" == 'none' ]; then
  throw_info "Two factor authentication NOT installed."
elif [ "$TWO_FA" == 'totp' ]; then
    enable_totp_2fa
elif nc -v -w 1 -z free-2fa-sender.rport.io 443 2>/dev/null;then
  throw_debug "Connection to free-2fa-sender.rport.io port 443 succeeded."
  enable_email_2fa
else
  throw_info "Outgoing https connections seem to be blocked."
  throw_waring "Two factor authentication NOT installed."
fi
## END of snippets/installer/07-enable-2fa.sh -----------|
## snippets/installer/08-install-frontend.sh -----------|
DOC_ROOT="/var/lib/rport/docroot"
test -e ${DOC_ROOT}&&rm -rf ${DOC_ROOT}
mkdir ${DOC_ROOT}
cd ${DOC_ROOT}
curl -LSs https://downloads.rport.io/frontend/${RELEASE}/latest.php -o rport-frontend.zip
unzip -qq rport-frontend.zip && rm -f rport-frontend.zip
cd ~
## Create a symbolic link of the ssl root-ca certificate so users can download the file with ease
if [ -n "$CA_CERT" ] && [ -e "$CA_CERT" ] ;then
  ln -s "$CA_CERT" ${DOC_ROOT}/rport-ca.crt
fi
chown -R rport:rport ${DOC_ROOT}
throw_info "The RPort Frontend has been installed from the latest ${RELEASE} release."

install_novnc
## END of snippets/installer/08-install-frontend.sh -----------|
## snippets/installer/09-install-guacd.sh -----------|
# Install guacd only if the rportd version and the distribution supports it.
install_guacd && activate_guacd

## END of snippets/installer/09-install-guacd.sh -----------|
## snippets/installer/99-finish.sh -----------|
echo -n "Status of your RPort server: "
## @Rainui: manual run of rportd
rportd -c /etc/rport/rportd.conf --log-level info &
if pgrep rportd>/dev/null 2>&1;then
  echo "Running :-)"
else
  echo "NOT RUNNING"
  echo "Check the logs in /var/log/rport/rportd.log"
  false
fi
SUMMARY="/root/rportd-installation.txt"
echo "RPortd installed $(date)
Admin URL: https://${FQDN}:${API_PORT}
User:      admin
Password:  $ADMIN_PASSWD
${TWO_FA_MSG}
">$SUMMARY
echo "------------------------------------------------------------------------------"
echo " TATAA!!  All finished "
echo ""
sleep 0.3
echo " ----> Let's get started <----"
echo " Point your browser to https://${FQDN}:${API_PORT} "
echo " Login with:"
echo "    User     = admin"
echo "    Password = $ADMIN_PASSWD"
echo ""
echo " ${TWO_FA_MSG}"
echo "------------------------------------------------------------------------------"

## END of snippets/installer/99-finish.sh -----------|
