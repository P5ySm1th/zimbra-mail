#!/bin/bash
RED='\033[0;31m'
NORMAL='\033[0m'
GREEN='\033[0;32m'
YELLOW='\e[33m'
#==================
WORKDIRECTORY=$1
LOG=$WORKDIRECTORY"/logs/install.log"

touch $LOG
chmod +w $LOG

function logFile {
    if [ $1 -eq 0 ]; then
        echo "$(date): $2 $3 successfully $4" >> $LOG
    else
        echo "$(date): ERROR - $3 $2 failed with the exit code $1" >> $LOG
    fi
}
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

function checkSubnet {
    echo -e "${YELLOW}This DNS build is only use for /24 and /16 subnetmask. Do you want to continue? [Y/N]"
    read -p "INPUT: " INPUT
    
    while [[ ! ${INPUT} =~ ^[YNyn]$ ]]; do
        echo -e "${RED}Only Y or N!${NORMAL}"
        read -p 'Input again: ' INPUT
    done
    
    if [[ ${INPUT} == "Y" ]]; then
        while true; do
            read -p "Please enter your subnet mask for your system: " SUBNET_MASK
            echo -e "Are you sure that ${RED}${SUBNET_MASK}${NORMAL}? [Y/N]"
            read -p 'Input: ' INPUT
            
            while [[ ! ${INPUT} =~ ^[YNyn]$ ]]; do
                echo -e "${RED}Only Y or N!${NORMAL}"
                read -p 'Input again: ' INPUT
            done
            
            if [[ ${INPUT} == "Y" ]]; then
                if [[ ${SUBNET_MASK} == "24" || ${SUBNET_MASK} == "16" ]]; then
                    break
                else
                    echo -e "${RED}Invalid subnet mask! Please enter either 24 or 16.${NORMAL}"
                fi
            fi
        done

    else
        exit
    fi
}


function unchangeNameserver {
    read -p 'If you restart the OS, they will change /etc/resolv.conf to default, do you want the DNS you configure remain unchange in /etc/resolv.conf? [Y/N]: ' INPUT
    while [[ ! $INPUT =~ ^[YN]$ ]]; do
        echo -e "${RED}Only Y or N!${NORMAL}"
        read -p 'Input again: ' INPUT
    done
    if [[ $INPUT == "Y" ]]; then
    apt -y install resolvconf
    logFile $? "Install" "resolvconf"
    echo  -e ${RED}"Installed resolvconf"
    [[ ! -f /etc/resolvconf/resolv.conf.d/head ]] && mv /etc/resolvconf/resolv.conf.d/head /etc/resolvconf/resolv.conf.d/head.backup
    cat > /etc/resolv.conf <<- EOF
nameserver 8.8.8.8
nameserver ${PUBLIC_IP}
EOF
    service resolvconf restart
    cat /etc/resolv.conf
    fi
}
 

function main(){
   
    checkSubnet
    apt-get install -y bind9
    logFile $? "Install" "bind9"
    CONFDIR=/etc/bind
    if [[ ! -d "${CONFDIR}" ]]
    then
        echo -e ${RED}"ERROR: configuration path ${CONFDIR} does not exist, exiting"${NORMAL} >> $LOG
        exit 1
    else
        echo "Configuration path ${CONFDIR}" >> $LOG
        cd $CONFDIR || exit 1
    fi
    
}

main



#===============DIR PATH===============
NAMED_CONF_LOCAL=”/etc/bind/named.conf.local”
NAMED_CONF_OPTIONS="/etc/bind/named.conf.options"
NAMED_CONF_LOCAL="/etc/bind/named.conf.local"
#======================================
#$HOSTNAME, $DNS_IP, $DOMAIN

#mail.tientq.live
input "DNS hostname" "HOSTNAME" 
#tientq.live
input "domain" "DOMAIN"
input "DNS IP (Private IP)" "DNS_IP"
input "Public IP" "PUBLIC_IP"
cd $CONFDIR
sleep 1 & spinner $! "CREATING backup folders"
mkdir -p backup
logFile $? "Created" "zones folders" "at /etc/bind/"

dns_subnet24() {
  local DNS_IP=$DNS_IP
  local DOMAIN=$DOMAIN
  local CONFDIR=$CONFDIR
  local HOSTNAME=$HOSTNAME
  local PUBLIC_IP=$PUBLIC_IP
  local RED="\e[31m"

  spinner() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spin=('\' '|' '/' '-')
    local spin_idx=0

    echo -n "$message "

    while kill -0 $pid &>/dev/null; do
      local spin_char="${spin[spin_idx]}"
      echo -ne "\b$spin_char"
      sleep $delay
      spin_idx=$(( (spin_idx + 1) % 4 ))
    done
    echo -e "\b \n"
  }

  logFile() {
    local status=$1
    local action=$2
    local file_name=$3
    local location=$4

    if [ $status -eq 0 ]; then
      echo "Success: $action $file_name at $location"
    else
      echo "Error: Failed to $action $file_name at $location"
    fi
  }

  create_named_conf_options() {
    sleep 1 & spinner $! "CREATING NAMED.CONF.OPTIONS FILE"
    [[ ! -f named.conf.options.backup ]] && mv named.conf.options backup/named.conf.options.backup
    logFile $? "Created" "named.conf.local.backup" "at /etc/bind/backup/named.conf.options.backup"

    cat > named.conf.options <<- EOF
acl "Trusted" {
    ${DNS_IP};    # ns1 - can be set to localhost
};
options {
    directory "/var/cache/bind";
    recursion yes;
    allow-recursion { trusted; };
    listen-on { ${DNS_IP}; };
    allow-transfer { none; };
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
    dnssec-validation auto;
    listen-on-v6 { any; };
};
EOF

      logFile $? "Created" "named.conf.options"
      echo -e ${RED}"Created named.conf.options"
  }

  create_named_conf_local() {
    sleep 1 & spinner $! "CREATING NAMED.CONF.LOCAL FILE"
    [[ ! -f named.conf.local.backup ]] && mv named.conf.local backup/named.conf.local.backup
    logFile $? "Created" "named.conf.local.backup" "at /etc/bind/backup/named.conf.local.backup"

    REVADDR=$(for FIELD in 3 2 1; do printf "$(echo ${DNS_IP} | cut -d '.' -f $FIELD)."; done)

    cat > named.conf.local <<- EOF
zone "${DOMAIN}" {
    type master;
    file "${CONFDIR}/zones/db.fwd.${DOMAIN}";
    allow-transfer { ${DNS_IP}; };
};
zone "${REVADDR}in-addr.arpa" {
    type master;
    file "${CONFDIR}/zones/db.rev.${DOMAIN}";
    allow-transfer { ${DNS_IP}; };
};
EOF

      logFile $? "Created" "named.conf.local"
      echo -e ${RED}"Created named.conf.local"
  }

  create_zones_folders() {
    mkdir -p /etc/bind/zones
    sleep 1 & spinner $! "CREATING zones folders"
    logFile $? "Created" "zones folders" "at /etc/bind/"
  }

  create_forward_zone() {
    sleep 1 & spinner $! "CREATING FORWARD ZONE FOR DNS SERVER"
    cat > zones/db.fwd.${DOMAIN} <<- EOF
\$TTL   604800
@       IN      SOA     ${HOSTNAME}. root.${HOSTNAME}. (
                2               ; Serial
                604800          ; Refresh
                86400           ; Retry
                2419200         ; Expire
                604800          ; Negative Cache TTL
                )
              IN      NS      ${HOSTNAME}.
      ;
${HOSTNAME}.          IN      A       ${DNS_IP}
EOF

      logFile $? "Created" "db.fwd.${DOMAIN}" "at ${CONFDIR}/zones"
      echo  -e ${RED}"Created db.fwd.${DOMAIN} at /etc/bind/zones/"
  }

  create_reverse_zone() {
    sleep 1 & spinner $! "CREATING REVERSE ZONE FOR DNS SERVER"
    NETWORK="$(echo ${DNS_IP} | cut -d '.' -f 4)"
    cat > zones/db.rev.${DOMAIN} <<- EOF
\$TTL   604800
@       IN      SOA     ${HOSTNAME}. root.${HOSTNAME}. (
                5               ; Serial
                604800          ; Refresh
                86400           ; Retry
                2419200         ; Expire
                604800          ; Negative Cache TTL
                )
            IN      NS      ${HOSTNAME}.
      ;
${NETWORK}          IN      PTR       ${HOSTNAME}.
EOF

      logFile $? "Created" "db.rev.${DOMAIN}" "at ${CONFDIR}/zones"
      echo  -e ${RED}"Created db.rev.${DOMAIN} at /etc/bind/zones/"
  }

  update_resolv_conf() {
    [[ ! -f /etc/resolv.conf.backup ]] && mv /etc/resolv.conf /etc/resolv.conf.backup
    logFile $? "Created" "reslov.conf.backup" "at /etc/"

    cat > /etc/resolv.conf <<- EOF
domain ${DOMAIN}
search ${DOMAIN}
nameserver ${PUBLIC_IP}
nameserver 8.8.8.8
EOF

    logFile $? "Add" "DNS server into /etc/resolve.conf"
    sleep 1 & spinner $! "Adding the DNS server to this PC"
  }

  changeEtcHost(){
    sleep 1 & spinner $! "Changing /etc/hosts"
    echo "${DNS_IP} ${HOSTNAME}" >> /etc/hosts
  }
  restart_bind_service() {
    sleep 1 & spinner $! "Restarting bind9 service"
    hostnamectl set-hostname ${HOSTNAME}
    systemctl restart bind9
    chown root:bind -R /etc/bind

    unchangeNameserver
  }

  create_named_conf_options
  create_named_conf_local
  create_zones_folders
  create_forward_zone
  create_reverse_zone
  update_resolv_conf
  restart_bind_service
  changeEtcHost

  echo "Done."
}


dns_subnet16() {
  local DNS_IP=$DNS_IP
  local DOMAIN=$DOMAIN
  local CONFDIR=$CONFDIR
  local HOSTNAME=$HOSTNAME
  local PUBLIC_IP=$PUBLIC_IP
  local RED="\e[31m"

  spinner() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spin=('\' '|' '/' '-')
    local spin_idx=0

    echo -n "$message "

    while kill -0 $pid &>/dev/null; do
      local spin_char="${spin[spin_idx]}"
      echo -ne "\b$spin_char"
      sleep $delay
      spin_idx=$(( (spin_idx + 1) % 4 ))
    done
    echo -e "\b \n"
  }

  logFile() {
    local status=$1
    local action=$2
    local file_name=$3
    local location=$4

    if [ $status -eq 0 ]; then
      echo "Success: $action $file_name at $location"
    else
      echo "Error: Failed to $action $file_name at $location"
    fi
  }

  create_named_conf_options() {
    sleep 1 & spinner $! "CREATING NAMED.CONF.OPTIONS FILE"
    [[ ! -f named.conf.options.backup ]] && mv named.conf.options backup/named.conf.options.backup
    logFile $? "Created" "named.conf.local.backup" "at /etc/bind/backup/named.conf.options.backup"

    cat > named.conf.options <<- EOF
acl "Trusted" {
    ${DNS_IP};    # ns1 - can be set to localhost
};
options {
    directory "/var/cache/bind";
    recursion yes;
    allow-recursion { trusted; };
    listen-on { ${DNS_IP}; };
    allow-transfer { none; };
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
    dnssec-validation auto;
    listen-on-v6 { any; };
};
EOF

      logFile $? "Created" "named.conf.options"
      echo -e ${RED}"Created named.conf.options"
  }

  create_named_conf_local() {
    sleep 1 & spinner $! "CREATING NAMED.CONF.LOCAL FILE"
    [[ ! -f named.conf.local.backup ]] && mv named.conf.local backup/named.conf.local.backup
    logFile $? "Created" "named.conf.local.backup" "at /etc/bind/backup/named.conf.local.backup"

    REVADDR=$(for FIELD in 2 1; do printf "$(echo ${DNS_IP} | cut -d '.' -f $FIELD)."; done)

    cat > named.conf.local <<- EOF
zone "${DOMAIN}" {
    type master;
    file "${CONFDIR}/zones/db.fwd.${DOMAIN}";
    allow-transfer { ${DNS_IP}; };
};
zone "${REVADDR}in-addr.arpa" {
    type master;
    file "${CONFDIR}/zones/db.rev.${DOMAIN}";
    allow-transfer { ${DNS_IP}; };
};
EOF

      logFile $? "Created" "named.conf.local"
      echo -e ${RED}"Created named.conf.local"
  }

  create_zones_folders() {
    mkdir -p /etc/bind/zones
    sleep 1 & spinner $! "CREATING zones folders"
    logFile $? "Created" "zones folders" "at /etc/bind/"
  }

  create_forward_zone() {
    sleep 1 & spinner $! "CREATING FORWARD ZONE FOR DNS SERVER"
    cat > zones/db.fwd.${DOMAIN} <<- EOF
\$TTL   604800
@       IN      SOA     ${HOSTNAME}. root.${HOSTNAME}. (
                2               ; Serial
                604800          ; Refresh
                86400           ; Retry
                2419200         ; Expire
                604800          ; Negative Cache TTL
                )
              IN      NS      ${HOSTNAME}.
      ;
${HOSTNAME}.          IN      A       ${DNS_IP}
EOF

      logFile $? "Created" "db.fwd.${DOMAIN}" "at ${CONFDIR}/zones"
      echo  -e ${RED}"Created db.fwd.${DOMAIN} at /etc/bind/zones/"
  }

  create_reverse_zone() {
    sleep 1 & spinner $! "CREATING REVERSE ZONE FOR DNS SERVER"
    NETWORK=$(for FIELD in 4 3; do printf "$(echo ${DNS_IP} | cut -d '.' -f $FIELD)"; done)
    cat > zones/db.rev.${DOMAIN} <<- EOF
\$TTL   604800
@       IN      SOA     ${HOSTNAME}. root.${HOSTNAME}. (
                5               ; Serial
                604800          ; Refresh
                86400           ; Retry
                2419200         ; Expire
                604800          ; Negative Cache TTL
                )
            IN      NS      ${HOSTNAME}.
      ;
${NETWORK}          IN      PTR       ${HOSTNAME}.
EOF

      logFile $? "Created" "db.rev.${DOMAIN}" "at ${CONFDIR}/zones"
      echo  -e ${RED}"Created db.rev.${DOMAIN} at /etc/bind/zones/"
  }

  update_resolv_conf() {
    [[ ! -f /etc/resolv.conf.backup ]] && mv /etc/resolv.conf /etc/resolv.conf.backup
    logFile $? "Created" "reslov.conf.backup" "at /etc/"

    cat > /etc/resolv.conf <<- EOF
domain ${DOMAIN}
search ${DOMAIN}
nameserver ${PUBLIC_IP}
nameserver 8.8.8.8
EOF

    logFile $? "Add" "DNS server into /etc/resolve.conf"
    sleep 1 & spinner $! "Adding the DNS server to this PC"
  }

  restart_bind_service() {
    sleep 1 & spinner $! "Restarting bind9 service"
    hostnamectl set-hostname ${HOSTNAME}
    systemctl restart bind9
    chown root:bind -R /etc/bind

    unchangeNameserver
  }
  changeEtcHost(){
    sleep 1 & spinner $! "Changing /etc/hosts"
    echo "${DNS_IP} ${HOSTNAME}" >> /etc/hosts
  }
  create_named_conf_options
  create_named_conf_local
  create_zones_folders
  create_forward_zone
  create_reverse_zone
  update_resolv_conf
  restart_bind_service
  changeEtcHost
  echo "Done."
}


if [[ $SUBNET_MASK == '24' ]]; then
    dns_subnet24
else
    dns_subnet16
fi