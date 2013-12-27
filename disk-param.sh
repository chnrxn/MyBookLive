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
