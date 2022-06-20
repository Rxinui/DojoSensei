#!/bin/bash
RPORT_DIR="$(dirname $(realpath $0))/scripts/"
EXIT_ROOT_USER=101
EXIT_SETUP_USER_NULL=102


if [[ $# -eq 0 || $1 == "-h" || $1 == "--help" ]]; then
    cat <<EOF
setup.sh: Use this setup script to run various installer at once.

Usage: sudo ./setup.sh --user <SETUP_USER> [-OPTION] [-OPTION2] ...

Options: options are case-sensitive

    -rport: Install rport client.
    -vncserver: Install TurboVNC server.    
EOF
fi

## Parsing args
while [ $# -gt 0 ]; do
    case $1 in
    "-rport")
        RUN_RPORT=1
        ;;
    "-vncserver")
        RUN_VNCSERVER=1
        ;;
    "-ttyd")
        RUN_TTYD=1
        ;;
    "--uninstall" | "-u")
        UNINSTALL=1
        ;;
    "--dry" | "-d")
        DRY_RUN=1
        ;;
    "--configure" | "-c")
        CONFIGURE=1
        ;;
    "--user")
        shift 1
        SETUP_USER=$1
        ;;
    "--install" | "-i")
        INSTALL=1
        ;;
    esac
    shift 1
done

## Functions
create_service() {
    echo "> Create service"
    echo "[Unit]
Description=Dojoplateforme configuration for rport service
After=network-online.target graphical.target

[Service]
Type=oneshot
User=$SETUP_USER
RemainAfterExit=yes
ExecStart=/opt/TurboVNC/bin/vncserver -securitytypes none,tlsnone,x509none -xstartup /home/$SETUP_USER/.vnc/xstartup :1 
# ExecStart=/home/$SETUP_USER/.rport/setup.sh --user $SETUP_USER -c -vncserver
ExecStop=/opt/TurboVNC/bin/vncserver -kill :1
TimeoutStartSec=15

[Install]
WantedBy=graphical.target multi-user.target" > /etc/systemd/system/dojo-rport.service
}

## Pre-conditions
if [ $(id -u) -eq 0 ]; then
    if [ $CONFIGURE ]; then
        echo "Please, run setup.sh as non-root user when using 'configure' command."
        exit $EXIT_ROOT_USER
    fi
fi
if [ ! $SETUP_USER ]; then
    if [ $CONFIGURE ]; then
        echo "Please, define a user using --user option when using 'configure' command."
        exit $EXIT_SETUP_USER_NULL
    fi
fi

## Scheduling scripts
if [ $RUN_RPORT ]; then
    . $RPORT_DIR/env_rport.sh
    if [ $UNINSTALL ]; then
        bash $RPORT_DIR/install_rport.sh -u
    elif [ $DRY_RUN ]; then
        bash $RPORT_DIR/install_rport.sh -d
    elif [ $CONFIGURE ]; then
        $RPORT_DIR/configure_rport.sh
    else
        bash $RPORT_DIR/install_rport.sh -s -x -i && create_service
    fi
fi
if [ $RUN_VNCSERVER ]; then
    if [ $UNINSTALL ]; then
        apt remove -y turbovnc
    elif [ $CONFIGURE ]; then
        # SETUP_USER=$SETUP_USER $RPORT_DIR/configure_vncserver.sh
        SETUP_USER=$SETUP_USER $RPORT_DIR/configure_vncserver.sh && sleep 2 && $RPORT_DIR/configure_rport.sh -vncserver
    else
        $RPORT_DIR/install_vncserver.sh
    fi
fi

if [ $RUN_TTYD ]; then
    if [ $INSTALL ]; then
        wget -O /opt/ttyd "https://github.com/tsl0922/ttyd/releases/download/1.6.3/ttyd.$(uname -m)"
        chmod 755 /opt/ttyd
        $RPORT_DIR/configure_rport.sh -ttyd
    fi
fi

