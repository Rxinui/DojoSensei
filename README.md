# DojoSensei

GitHub repository for **sensei** of [DojoPlateforme](https://github.com/Rxinui/DojoPlateforme)

## Introduction

This repository contains all resources needed by **sensei** such as guidelines and installation scripts.

To make a virtual machine image usable by [DojoPlateforme](https://github.com/Rxinui/DojoPlateforme), it is required to install `rport` client in each VM before exporting it as an image. `rport` is used to register a VM to `rportd` server which manage DojoPlateforme's tunnels.

Afterwards, you can choose between `ttyd` and `turbovnc` (according to your need) to make your VM accessible by the DojoPlateforme's users.

Further documentations:
- [rport](https://oss.rport.io/docs/#quick-start)
- [ttyd](https://tsl0922.github.io/ttyd/)
- [turbovnc](https://rawcdn.githack.com/TurboVNC/turbovnc/3.0beta1/doc/index.html)

## Pre-requisites

You must clone this repository with `git` in the following directory `/opt`. If needed, please create the `/opt` directory.

```bash
git clone https://github.com/Rxinui/DojoSensei.git -b main --single-branch /opt
```

## Packages 
### [Required] `rport`

**Required**. To create a Virtual Machine supported by [DojoPlateforme](https://github.com/Rxinui/DojoPlateforme), it is necessary to install `rport` client. `rport` is mandatory to communicate with `rportd` server which manage tunnels from virtuals machine to end-to-end user. 

Go to `./rport/` directory and use the `setup.sh` script as root user
#### Install

```bash
cd /opt/DojoSensei/rport/ && \
sudo ./setup.sh i # i as install
```

The installation using `setup.sh` implies:
- installation of `rport` package
- creation of `rport.service` that starts the service when creating a new instance of this VM

#### Uninstall

```bash
cd /opt/DojoSensei/rport/ && \
sudo ./setup.sh u # u as uninstall
```

### `ttyd`

**Need: give access to a virtual machine's terminal**

Go to `./ttyd/` directory and use the `setup.sh` script as root user
#### Install

```bash
cd /opt/DojoSensei/ttyd/ && \
sudo ./setup.sh i # i as install
```

The installation using `setup.sh` implies:
- installation of `ttyd` package, which give a HTTP access to a virtual machine's terminal (using port `7681`)
- creation of `ttyd.service` that starts the service when creating a new instance of this VM

#### Uninstall

```bash
cd /opt/DojoSensei/ttyd/ && \
sudo ./setup.sh u # u as uninstall
```

### `turbovnc`

**Need: give access to a virtual machine's graphical environment**

Go to `./turbovnc/` directory and use the `setup.sh` script as root user

#### Install

```bash
cd /opt/DojoSensei/turbovnc/ && \
sudo ./setup.sh i --user <username> # i as install
```

where `<username>` is the user account to make accessible through HTTP.

The installation using `setup.sh` implies:
- installation of `turbovnc` package in `/opt`, which give a HTTP access to a virtual machine's graphical environment using VNC protocol (using port `5905`)
- creation of `turbovnc.service` that starts the service when creating a new instance of this VM (**bug: does not start automatically at boot**)

#### Uninstall

1. Go to `./turbovnc/` directory
2. Use the `setup.sh` script as root user

```bash
cd /opt/DojoSensei/turbovnc/ && \
sudo ./setup.sh u # u as uninstall
```
## Export a VM as image file

Follow this guideline to export a VM (according to its type) as an image for [DojoPlateforme](https://github.com/Rxinui/DojoPlateforme)

### VirtualBox: .ova file v2

1. After setting up your virtual machine, turn it off.
2. On VirtualBox GUI, right-click on the virtual machine and do: `Export to OCI`
3. Choose `Open Virtualization Format 2.0` as exportation format
4. Choose your `MAC Address policy` that suits the most
5. Select `Write manifest file` and unselect `Include ISO image files`
6. Click on button `Next` and fill the information asked
7. Create your VM's image by clicking on button `Export`

### Qemu

**Not implemented yet**

### Docker

**Not implemented yet**