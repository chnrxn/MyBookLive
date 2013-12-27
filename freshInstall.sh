#!/bin/sh
#
# � 2010 Western Digital Technologies, Inc. All rights reserved.
#
# freshInstall.sh
#

PATH=/sbin:/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
. /path/to/parted/disk-param.sh

# create the new disk partitions
./partitionDisk.sh

# clear out any old md superblock data
mdadm --zero-superblock --force --verbose ${rootfsDisk1} > /dev/null
mdadm --zero-superblock --force --verbose ${rootfsDisk2} > /dev/null
sync
mdadm --create ${rootfsDevice} --verbose --raid-devices=2 --level=raid1 --run ${rootfsDisk1} missing
mdadm --wait ${rootfsDevice}
sleep 1

# create the swap partition
mkswap ${disk}3

# format the rootfs raid mirror file system
mkfs.ext3 -c -b 4096 ${rootfsDevice} 

# format the data volume file system
mkfs.ext4 -b 65536 -m 0 ${disk}4
#mkfs.xfs -f -b size=65536 ${disk}4

sync
sleep 2

# mount and configure the data volume

# add the second partition to the raid mirror
mdadm ${rootfsDevice} --add --verbose ${rootfsDisk2}
sleep 1
echo
echo "Please wait for raid RE-SYNC to complete.."
sleep 1
mdadm --wait ${rootfsDevice}
mdadm --detail ${rootfsDevice}
echo "Done."
sync
# a reboot is performed by the caller
