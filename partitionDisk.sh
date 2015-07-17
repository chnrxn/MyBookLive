#!/bin/sh
#
# � 2010 Western Digital Technologies, Inc. All rights reserved.
#
# partitionDisk.sh
#

PATH=/sbin:/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

. /path/to/disk-param.sh

# Apollo 3G parition layout:
#
# /dev/md0 -RFS
#       /dev/${disk}1 - RFS (main)
#       /dev/${disk}2 - RFS (backup)
#/dev/${disk}3 - swap
#/dev/${disk}4 - /DataVolume (includes /var)
#

echo "Partition Disk: ${disk}..."

backgroundPattern="${backgroundPattern:-0}"

#
# this script assumes that all preparatory steps have already been taken!
#

# clear any old partitioning data, etc.
if [ -e "${disk}1" ]; then
        dd if=/dev/zero of=${disk}1 bs=1M count=32
fi
if [ -e "${disk}2" ]; then
        dd if=/dev/zero of=${disk}2 bs=1M count=32
fi
if [ -e "${disk}3" ]; then
        dd if=/dev/zero of=${disk}3 bs=1M count=32
fi
if [ -e "${disk}4" ]; then
        dd if=/dev/zero of=${disk}4 bs=1M count=32
fi
if [ -e "${disk}" ]; then
    # use badblocks here to preseve any background pattern
    badblocks -swf -b 1048576 -t ${backgroundPattern} ${disk} 16 0
fi
sync
sleep 2

#parted $disk mklabel msdos

# use a 'here document' to allow parted to understand the -1M
parted $disk --align optimal <<EOP
mklabel gpt
mkpart primary 528M  2576M
mkpart primary 2576M 4624M
mkpart primary 16M 528M
mkpart primary 4624M -1M
set 1 raid on
set 2 raid on
quit
EOP

#parted $disk --align optimal <<EOP
#mklabel gpt
#mkpart primary 16M   2064M
#mkpart primary 2064M 4112M
#mkpart primary 4112M 4624M
#mkpart primary 4624M -1M
#set 1 raid on
#set 2 raid on
#quit
#EOP
# 2064 - 16 = 2048
# 4112 - 2064 = 2048
# 4624 - 4112 = 512
#

sync
sleep 1
parted $disk print
