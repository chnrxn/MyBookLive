#!/bin/bash
#
# � 2010 Western Digital Technologies, Inc. All rights reserved.
#
# updateFirmwareFromFile.sh <filename>
#
#

#---------------------
# add stderr to stdout
exec 2>&1

PATH=/sbin:/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
. /usr/local/sbin/share-param.sh
. /usr/local/sbin/disk-param.sh

source /etc/system.conf

SYSTEM_SCRIPTS_LOG=${SYSTEM_SCRIPTS_LOG:-"/dev/null"}
# Output script log start info
{
echo "Start: `basename $0` `date`"
echo "Param: $@"
} >> ${SYSTEM_SCRIPTS_LOG}
#
{
#---------------------
# Begin Script
#---------------------

restoreRaid ()
{
    currentRootDevice=`cat /proc/cmdline | awk '/root/ { print $1 }' | cut -d= -f2`
    duplicate_md=
    if [ "${currentRootDevice}" != "/dev/nfs" ]; then
        # stop any duplicate md devices and make sure both disks are part of the current rootfs md device
        if [ "${currentRootDevice}" == "/dev/md0" ]; then
            if [ -e /dev/md1 ]; then
                duplicate_md="/dev/md1"
            fi
        elif [ "${currentRootDevice}" == "/dev/md1" ]; then
            if [ -e /dev/md0 ]; then
                duplicate_md="/dev/md0"
            fi
        fi
        if [ ! -z ${duplicate_md} ]; then
            echo "stopping duplicate md device ${duplicate_md}"
            mdadm --stop ${duplicate_md}
            mdadm --wait ${duplicate_md}
            sleep 1
        fi
        # always attempt to add both mirror partitions - its ok to fail if they are already there
        mdadm ${currentRootDevice} --add ${rootfsDisk1} > /dev/null 2>&1
        mdadm --wait ${currentRootDevice}
        mdadm ${currentRootDevice} --add ${rootfsDisk2} > /dev/null 2>&1
        mdadm --wait ${currentRootDevice}
        sleep 1
    fi
}

filename=${1}
updatelog="/CacheVolume/update.log"

if [ $# != 1 ]; then
        echo "usage: updateFirmwareFromFile.sh <filename>"
        exit 1
fi

if [ ! -f ${filename} ]; then
        echo "File not found"
        exit 1
fi

# check disk usage
dfout=`df | grep /DataVolume`
avail=`echo "$dfout" | awk '{printf("%d",$2-$3)}'`
if [ "${avail}" -lt "${fwUpdateSpace}" ]; then
        error="failed 201 \"not enough space on device for upgrade\""
        echo  ${error} > /tmp/fw_update_status
        echo ${error}
        exit 1
fi

# ITR No. 34229 Abstract: 3.5G allows down rev code to be applied from file
version_current=`cat /etc/version | tr -d .-`
version_newfile=`dpkg -f ${filename} Version`
version_newfile=`echo ${version_newfile} | tr -d .-`
echo "version_newfile=$version_newfile"
echo "version_current=$version_current"
package_newfile=`dpkg -f ${filename} Package`
echo "package_newfile=$package_newfile"
echo "master_package_name=$master_package_name"

if [ "${master_package_name}" != "${package_newfile}" ] || [ "${version_newfile}" -lt "${version_current}" ]; then
        error="failed 200 \"invalid firmware package\""
        echo ${error} > /tmp/fw_update_status
        echo "Error: $0 (${filename}) version ($version_newfile) is less than current system version ($version_current)"
        echo "Error: $0 (${filename}) version ($version_newfile) is less than current system version ($version_current)" | logger
        exit 1
fi

old_color=`cat /usr/local/nas/led_color`
echo white > /usr/local/nas/led_color
#upgrade
dpkg -i ${filename} 2>&1 | tee ${updatelog} > /dev/null
status=$?

# remove update files
rm -f /CacheVolume/*.deb

cat ${updatelog} | grep -q "not a debian format archive"
if [ $? -eq 0 ]; then
        error="failed 200 \"invalid firmware package\""
        echo  ${error} > /tmp/fw_update_status
        echo ${error}
        restoreRaid
        if [ "$old_color" == "red" ]; then
            echo "red" > /usr/local/nas/led_color
        else
            echo "green" > /usr/local/nas/led_color
        fi
        exit 1
fi
if [ ${status} -ne 0 ]; then
        echo "dkpg exited with non-zero status: ${status}"
        error="Update failed. Check ${updatelog} for details."
        echo  ${error} > /tmp/fw_update_status
        echo ${error}
        restoreRaid
        if [ "$old_color" == "red" ]; then
                echo "red" > /usr/local/nas/led_color
        else
                echo "green" > /usr/local/nas/led_color
        fi
fi

#---------------------
# End Script
#---------------------
# Copy stdout to script log also
} | tee -a ${SYSTEM_SCRIPTS_LOG}
# Output script log end info
{
echo "End:$?: `basename $0` `date`"
echo ""
} >> ${SYSTEM_SCRIPTS_LOG}

exit ${status}
share-param.sh
#!/bin/sh
#
# ? 2010 Western Digital Technologies, Inc. All rights reserved.
#

###########################################
# share setup files
###########################################
trustees=/etc/trustees.conf
sambaOverallShare=/etc/samba/overall_share
hostsConfig=/etc/hosts
networkConfig=/etc/network/interfaces
dnsConfig=/etc/resolv.conf
dhclientConfig=/etc/dhcp3/dhclient.conf
ntpConfig=/etc/default/ntpdate
smbConfig=/etc/samba/smb.conf
remoteAccessConfig=/etc/remote_access.conf
itunesConfig=/etc/forked-daapd.conf
upgrade_link=/tmp/fw_upgrade_link

userConfig=/etc/passwd
passwdConfig=/etc/shadow
smbpasswdConfig=/etc/samba/smbpasswd

ownerUid=999
adminDefaultAlias="admin-dfalias-wd"

# 3G required for F/W update
fwUpdateSpace="3000000"

fileTally=/var/local/nas_file_tally
twonky_dir=/usr/local/twonkymedia-5

# bash scripts logging for debugging use.. currently not all scripts are instrumented.
# SYSTEM_SCRIPTS_LOG="/var/log/wdscripts.log"
disk-param.sh
#!/bin/sh

###########################################
# ? 2010 Western Digital Technologies, Inc. All rights reserved.
#
# definition list for a 1NC product
###########################################
factoryRestoreSettings=/etc/.factory_restore_settings
reformatDataVolume=/etc/.reformat_data_volume
diskWarningThresholdReached=/etc/.freespace_failed

disk=/dev/sdf

dataVolumeDevice="${disk}4"
swapDevice="${disk}3"
rootfsDevice="/dev/md0"
rootfsDisk1="${disk}1"
rootfsDisk2="${disk}2"

blockSize=64k
blockCount=31247

# The fill pattern needs to be verified for every release to manufacturing
backgroundPattern=0xE5
