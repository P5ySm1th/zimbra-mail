#!/bin/bash
RED='\033[0;31m'
NORMAL='\033[0m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
#==================
DIRECTORY=$(pwd)
VERSION=$(lsb_release -rs)
USER=$(whoami)
OS=$(uname -s)
KERNEL=$(uname -r)
MACH=$(uname -m)
#==================

spinner() {
    local PROC="$1"
    local str="$2"
    local delay="0.1" 
    tput civis
    printf "\033[1;34m"
    while [ -d /proc/$PROC ]; do
        printf '\033[s\033[u[ / ] %s\033[u' "$str"; sleep "$delay"
        printf '\033[s\033[u[ — ] %s\033[u' "$str"; sleep "$delay"
        printf '\033[s\033[u[ \ ] %s\033[u' "$str"; sleep "$delay"
        printf '\033[s\033[u[ | ] %s\033[u' "$str"; sleep "$delay"
    done
    printf '\033[s\033[u%*s\033[u\033[0m' $((${#str}+6)) " "
    tput cnorm
    return 0
}
checkKernelLinux(){
    sleep 1 & spinner $! "CHECKING FOR USERNAME"
    echo -e "${RED}USERNAME: ${USER}"
    sleep 1 & spinner $! "CHECKING LINUX VERSION"
    echo -e "${RED}CHECKING VERSION: ${VERSION}"
    sleep 1 & spinner $! "CHECKING LINUX VERSION"
    if [[ $OS == 'Linux' ]]; then
        if [ -f /etc/redhat-release ] ; then
            DIST='RedHat'
        elif [ -f /etc/debian_version ] ; then
            DIST="`cat /etc/debian_version`"
        fi
    else
        echo -e "${RED}WARNING: THIS TOOL ONLY USE FOR LINUX OS${NORMAL}"
    fi
    echo -e "${RED}CHECKING KERNEL: $KERNEL${NORMAL}"
    echo -e "${RED}CHECKING MACH: $MACH${NORMAL}"
}

function checkHavingPrivateIP() {
  while true; do
    echo -e "Are you using ${RED}PRIVATE IP${NORMAL} as well as ${RED}PUBLIC IP ${NORMAL} while DNS installation? (Y/N)"
    read -p "INPUT: " INPUT
    while [[ ! $INPUT =~ ^[YNyn]$ ]]; do
      echo -e "${RED}Only Y or N!${NORMAL}"
      read -p 'Input again: ' INPUT
    done
    
    if [[ $INPUT == "Y" ]]; then
      checkKernelLinux
      chmod +x ./shell/linuxPrivateIP.sh
      bash ./shell/linuxPrivateIP.sh $DIRECTORY
      break
    else
      checkKernelLinux
      chmod +x ./shell/linuxPublicIP.sh
      bash ./shell/linuxPublicIP.sh $DIRECTORY
      break
    fi
  done
}

checkForInstall(){
  while true; do
    read -p "Do you wish to install DNS server? (Y/N): " INPUT
    case $INPUT in
      [Yy]* )
        checkHavingPrivateIP
        break;;
      [Nn]* )
        echo -e "${GREEN}Goodbye, never see you again!${NORMAL}"
        break;;
      * )
        echo -e "${RED}Please answer YES or NO and try again${NORMAL}";;
    esac
  done
}

if [[ ${USER} == "root" ]]; then
  checkForInstall
else
  echo -e "${RED}PLEASE RUN AS ROOT USER${NORMAL}"
fi

exit
