#!/bin/bash
RED='\033[0;31m'
NORMAL='\033[0m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
USER=$(whoami)
HOSTNAME=$(hostname)
function input {
    while true; do
        read -p "Please enter ${1} for your system: " ${2}
        echo -e "Are you sure that ${RED}${2}${NORMAL} is your ${RED}${1}${NORMAL}? [Y/N]"
        read -p 'Input: ' INPUT
        while [[ ! ${INPUT} =~ ^[YNyn]$ ]]; do
            echo -e "${RED}Only Y or N!${NORMAL}"
            read -p 'Input again: ' INPUT
        done
        if [[ ${INPUT} == "N" ]]; then
            echo -e "${YELLOW}Re-enter ${1} for your system:${NORMAL}"
            read -p "Please enter ${1} for your system: " ${2}
            echo -e "Are you sure that ${RED}${2}${NORMAL} is your ${RED}${1}${NORMAL}? [Y/N]"
            read -p 'Input: ' RECONFIRM
            while [[ ! ${RECONFIRM} =~ ^[YNyn]$ ]]; do
                echo -e "${RED}Only Y or N!${NORMAL}"
                read -p 'Input: ' RECONFIRM
            done
            if [[ ${RECONFIRM} == "N"  || ${RECONFIRM} == "n" ]]; then
                continue
            fi
        fi
        echo -e "${GREEN}COMPLETE CHANGING !!${NORMAL}"
        break
    done
}
function main {
    sudo apt remove -y --purge snapd
    sudo autoremove
    sudo apt update && sudo apt dist-upgrade -y
    sudo apt remove ntp
    sudo apt install -y chrony
    sudo systemctl start chrony
    sudo systemctl enable chrony
    sudo timedatectl set-timezone Asia/Ho_Chi_Minh
    sudo systemctl stop postfix
    sudo systemctl disable postfix
    sudo systemctl stop apparmor
    sudo systemctl disable apparmor
    sudo apt remove --purge snapd
    sudo apt remove --purge postfix
    sudo apt remove --purge apache2
    sudo echo net.ipv6.conf.all.disable_ipv6 = 1 >> /etc/sysctl.conf
    sudo echo net.ipv6.conf.default.disable_ipv6 = 1 >> /etc/sysctl.conf
    sudo echo net.ipv6.conf.lo.disable_ipv6 = 1 >> /etc/sysctl.conf
    sudo echo net.ipv6.conf.ens33.disable_ipv6 = 1 >> /etc/sysctl.conf
    sudo echo vm.swappiness = 1 >> /etc/sysctl.conf
    sysctl -p

    grep "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub
    sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"ipv6.disable=1\"|g" /etc/default/grub  
    grep "GRUB_CMDLINE_LINUX" /etc/default/grub
    sed -i "s|GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"ipv6.disable=1\"|g" /etc/default/grub
    sudo update-grub
    sudo apt update && sudo apt install -y ufw
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow 25/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw allow 587/tcp
    sudo ufw allow 993/tcp
    sudo ufw allow 995/tcp
    sudo ufw allow 9071/tcp
    sudo ufw allow 7071/tcp
    sudo ufw allow 123/udp
    sudo ufw allow 53/udp
    sudo ufw enable

    #sudo ufw enable
    sudo ufw status numbered
    sudo systemctl restart ufw && sudo systemctl status ufw
    grep "-A ufw-before-input -m conntrack --ctstate INVALID -j ufw-logging-deny" /etc/ufw/before.rules
    sed -i 's/-A ufw-before-input -m conntrack --ctstate INVALID -j ufw-logging-deny/# -A ufw-before-input -m conntrack --ctstate INVALID -j ufw-logging-deny/g' /etc/ufw/before.rules
    grep "-A ufw-before-input -m conntrack --ctstate INVALID -j DROP" /etc/ufw/before.rules
    sed -i 's/-A ufw-before-input -m conntrack --ctstate INVALID -j DROP/# -A ufw-before-input -m conntrack --ctstate INVALID -j DROP/g' /etc/ufw/before.rules
    sudo systemctl restart ufw && sudo systemctl status ufw
    file=$(find /etc/bind/zones/ -type f -name "db.fwd*")
    input "domain for installing MX record" "DOMAIN"
    echo "${DOMAIN}.       IN      MX   10 ${HOSTNAME}." >> "$file"
    cd /tmp
    wget -c https://files.zimbra.com/downloads/8.8.15_GA/zcs-8.8.15_GA_4179.UBUNTU20_64.20211118033954.tgz
    tar -xzvf zcs-8.8.15_GA_4179.UBUNTU20_64.20211118033954.tgz
    cd zcs-8.8.15_GA_4179.UBUNTU20_64.20211118033954
    sudo ./install.sh
    su zimbra
    zmcontrol status
}
if [[ ${USER} == "root" ]]; then
  main
else
  echo -e "${RED}PLEASE RUN AS ROOT USER${NORMAL}"
fi

exit