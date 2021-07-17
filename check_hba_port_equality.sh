#!/usr/bin/env bash
###########################################################################################
:<<'__DOCUMENTATION-BLOCK__'
###########################################################################################
NAME: check_hba_port_equality.sh
Author: Joe Huck
###########################################################################################
__DOCUMENTATION-BLOCK__
###########################################################################################

#Check if this system is a VM or not
if [[ $(dmidecode --string system-product-name | grep -ic vmware) -ge 1 ]]
then
    is_vm=1
else
    is_vm=0
fi

#We don't perform this check on a VM
if [[ ${is_vm} -eq 1 ]]
then
    exit 1
fi

#check if symlink provided by release pacakge exists and is readable if so use it to determine os type
if [[ -e /etc/system-release && -L /etc/system-release ]];then
    os_release=$(cat $(readlink -f /etc/system-release))
elif [[ -f /etc/oracle-release ]];then
    os_release=$(cat /etc/oracle-release)
elif [[ -f /etc/redhat-release ]];then
    os_release=$(cat /etc/redhat-release)
else
    os_release="Unsupported"
fi

if [[ ${os_release} != "Unsupported" ]]
then
    os_version=$(echo $os_release | awk '{print $5}')
    os_major_version=$(echo $os_version | cut -d'.' -f1)
else
    exit 1
fi


case ${os_major_version} in
5)
    for i in $(find /sys/class/fc_host -name 'host*' -type l -exec basename {} \;)
    do
        if grep -i -q -E 'online|running' /sys/class/scsi_host/${i}/state; then
            ((fc_host_online_counter=fc_host_online_counter+1))
        fi
    done
    hba_health_status=$(awk -v fc_host_online_counter="$fc_host_online_counter" 'BEGIN {print fc_host_online_counter % 2}')
    ;;

*)
    for i in $(find /sys/class/fc_host -name 'host*' -type l -exec basename {} \;)
    do
        if grep -i -q -E 'online|running' /sys/class/fc_host/${i}/port_state; then
            ((fc_host_online_counter=fc_host_online_counter+1))
        fi
    done
    hba_health_status=$(awk -v fc_host_online_counter="$fc_host_online_counter" 'BEGIN {print fc_host_online_counter % 2}')
    ;;
esac

if [[ ${hba_health_status} -eq 0 ]]; then
    echo "equal"
elif [[ ${hba_health_status} -gt 0 ]]; then
    echo "unequal"
else
    exit 1
fi

exit 0
