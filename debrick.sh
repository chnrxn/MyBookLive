#!/bin/bash
#
# The purpose of the script is to reinstall the operating system (debrick) on 
# a harddrive that has been extracted from the housing of a WD MyBook Live.
#

#help screen
if  [ $# = 1 -a "$1" = "--help" ]; then
echo "
standard use of script is:
    sudo ./debricker.sh     the script will find out what disk to use, it will not
                            touch the partition tables and therefore perserves data.
                            it will look what the newest version of the firmware is
                            via internet and then search for it in current folder or
                            subfolders. if none is found it will download one.

possible options are:
    /dev/sd?                path to the disk from mybook live. if not given, the script 
                            will figure it out on its own.
    /*/*.img                path to the firmware that will be written to the disk. if 
                            not given, the script will search for and then download it.
    destroy                 script will rewrite the partition table of disk,
                            this will not perserve data, must match /dev/sd?.

example
    sudo ./debricker.sh /dev/sda /firmwares/mine.img destroy
"
exit 1
fi

echo

#check that requirements are fullfilled
if [ "$(id -u)" != "0" ]; then
    echo -e "this script must be run as root.\n"
    exit 1
fi
if ! which mdadm > /dev/null; then
    echo -e "this script requires the mdadm package.\n"
    exit 1
fi

#making sure the mountpoint is available
rootfsMount=/mnt/md0
if [ -e ${rootfsMount} ]; then
    if mountpoint -q ${rootfsMount}; then
        echo "${rootfsMount} needs to be unmounted."
        exit 1;
    fi
fi
test -d "./mnt" || mkdir -p "/mnt"
test -d "$rootfsMount" || mkdir -p "$rootfsMount"

#making sure that there is no raid unit running
rootfsRaid=/dev/md0
if [ -e $rootfsRaid ]; then
    echo -e "\n$rootfsRaid already exists! you need to stop and remove it.\n"
    exit 1;
fi

#standard choices
disk=notset
image_img=notset
destroy=false

#handles the arguments and sets options
for (( arg=1; arg<=${#}; arg++ ))
do
    case ${!arg} in
    /dev/sd?)    disk=${!arg};;
    *.img)        image_img=${!arg};;
    "destroy")    destroy=true;;
    *)             echo "unknown argument: ${!arg}" 
                exit 1
    esac
done

echo "********************** DISK           **********************"
echo

#figure out what disk to use
if [ $disk = "notset" ]; then
    for x in {a..z}
    do
        #avoid a to literal matching in order to avoid incompability.
        if [ -e /dev/sd${x} ];                                then
        diskTest=$(parted --script /dev/sd${x} print)
        if [ ! -e /dev/sd${x}0 -a ! -e /dev/sd${x}5 ];            then
        if [[ $diskTest = *WD??EARS* ]];                        then
        if [[ $diskTest = *??00GB* ]];                            then
        if [[ $diskTest = *3*B*B*5??MB*primary* ]];                then
        if [[ $diskTest = *1*B*B*2???MB*ext3*primary*raid* ]];    then
        if [[ $diskTest = *2*B*B*2???MB*ext3*primary*raid* ]];    then
        if [[ $diskTest = *4*B*B*GB*ext4*primary* ]];            then
            if [ $disk != notset ];                                then
                echo "multiple disk founds, you must enter the path manually:"
                echo "   sudo ./debricker.sh /dev/sd?"
                exit 1;
            fi
            disk=/dev/sd${x}
        fi; fi; fi;    fi;    fi;    fi; fi; fi
    done

    if [ $disk == notset ]; then
        echo "script could not find a matching sd unit connected to system."
        exit 1
    fi
else
    if [ ! -e $disk ]; then
        echo "$disk does not exist."
        exit 1;
    fi
fi

echo -e "script will use the following disk: \n"
parted --script $disk print
read -p "is this REALLY the disk you want? [y] " -n 1
if ! [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\nuser did not confirm, nothing was done.\n"
    exit 1;
fi
echo

diskRoot1=${disk}1
diskRoot2=${disk}2
diskSwap=${disk}3
diskData=${disk}4

echo
echo "********************** IMAGE          **********************"
echo

#the image was not given as parameter
if [ $image_img = notset ]; then
    #find out what the latest version of firmware is
    if ! which curl > /dev/null; then
        echo -e "\nthis script requires the curl package, either install it or specify image file.\n"
        exit 1
    fi
    wdc_homepage="http://websupport.wdc.com/firmware/list.asp"
    wdc_latestfirmware=$(curl "${wdc_homepage}?type=AP1NC&fw=01.03.03" 2> /dev/null | awk ' {
        if ( match($0, "upgrade file" ) != 0 ) {
            split($0, http, "\"");
            print http[2];
            exit 1;
        }
    }')
    latestversion_simple=$(echo $wdc_latestfirmware | cut -d'-' -f 2)
    latestversion_pattern=$(echo $latestversion_simple | sed 's/../&*/g;s/:$//')
    if [ "$latestversion_simple" == "" -o "$latestversion_pattern" == "" ]; then
        echo -e "\ncould not fetch the latest version!\n"
        exit 1;
    fi
    echo "checking:     ${latestversion_simple}"
    echo "searching:    ./*/*${latestversion_pattern}.img"
    image_img=$(find ./ -type f -name "*${latestversion_pattern}.img" -print; 2>/dev/null)

    #get the latest firmware either from subdirs or internet
    case `echo $image_img | wc -w` in
    0)  echo "searching:    ./*/*${latestversion_pattern}.deb"
        test -d "./firmware" || mkdir -p "./firmware"
        image_deb=$(find ./ -type f -name "*${latestversion_pattern}.deb" -print; 2>/dev/null)
        image_img="./firmware/rootfs_$latestversion_simple.img"
        if ! [ `echo $image_deb | wc -w` == 1 ]; then
            image_deb="./firmware/rootfs_$latestversion_simple.deb"
            echo
            echo "downloading:  $image_deb"
            read -p "confirm [y]:  " -n 1
            if ! [[ $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            echo
            curl $wdc_latestfirmware > $image_deb
            if [ $? != 0 ]; then
                echo -e "\ndownloading encountered problems.\n"
                exit 1;
            fi
        fi
        echo
        echo    "will extract: $image_deb"
        read -p "confirm [y]:  " -n 1
        echo
        if ! [[ $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        echo "extracting:   ./firmware/rootfs_${latestversion_simple}.img"
        ar p $image_deb data.tar.lzma | unlzma | tar -x -C ./firmware
        if [ $? != 0 ]; then
            echo -e "\nextraction encountered problems.\n"
            exit 1;
        fi
        mv ./firmware/CacheVolume/upgrade/rootfs.img ./firmware/rootfs_${latestversion_simple}.img
        rm -rf ./firmware/CacheVolume;;
    1)  echo "found:        $image_img";;
    *)  echo -e "\nmultiple image_img files was found."
        exit 1
    esac
else
    if [ ! -e $image_img ]; then
        echo "$image_img does not exist."
        exit 1;
    fi
fi

#construct the swap program
echo "\
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/mount.h>

#define MD_RESERVED_BYTES      (64 * 1024)
#define MD_RESERVED_SECTORS    (MD_RESERVED_BYTES / 512)

#define MD_NEW_SIZE_SECTORS(x) ((x & ~(MD_RESERVED_SECTORS - 1)) - MD_RESERVED_SECTORS)

main(int argc, char *argv[])
{
    int fd, i;
    unsigned long size;
    unsigned long long offset;
    char super[4096];
    if (argc != 2) {
        fprintf(stderr, \"Usage: swap_super device\\n\");
        exit(1);
    }
    fd = open(argv[1], O_RDWR);
    if (fd<0) {
        perror(argv[1]);
        exit(1);
    }
    if (ioctl(fd, BLKGETSIZE, &size)) {
        perror(\"BLKGETSIZE\");
        exit(1);
    }
    offset = MD_NEW_SIZE_SECTORS(size) * 512LL;
    if (lseek64(fd, offset, 0) < 0LL) {
        perror(\"lseek64\");
        exit(1);
    }
    if (read(fd, super, 4096) != 4096) {
        perror(\"read\");
        exit(1);
    }

    for (i=0; i < 4096 ; i+=4) {
        char t = super[i];
        super[i] = super[i+3];
        super[i+3] = t;
        t=super[i+1];
        super[i+1]=super[i+2];
        super[i+2]=t;
    }
    /* swap the u64 events counters */
    for (i=0; i<4; i++) {
        /* events_hi and events_lo */
        char t=super[32*4+7*4 +i];
        super[32*4+7*4 +i] = super[32*4+8*4 +i];
        super[32*4+8*4 +i] = t;

        /* cp_events_hi and cp_events_lo */
        t=super[32*4+9*4 +i];
        super[32*4+9*4 +i] = super[32*4+10*4 +i];
        super[32*4+10*4 +i] = t;
    }

    if (lseek64(fd, offset, 0) < 0LL) {
        perror(\"lseek64\");
        exit(1);
    }
    if (write(fd, super, 4096) != 4096) {
        perror(\"write\");
        exit(1);
    }
    exit(0);

}" >./swap.c

gcc swap.c -o swap
rm swap.c

echo
echo "********************** IMPLEMENTATION **********************"

echo -e "
everything is now prepared!
device:       $disk
image_img:    $image_img
destroy:      $destroy\n"

read -p "this is the point of no return, continue? [y] " -n 1
echo
if ! [[ $REPLY =~ ^[Yy]$ ]]; then
    exit 1;
fi
echo

#rewrite the partition table
if [ $destroy = true ]; then
    backgroundPattern="${backgroundPattern:-0}"

    dd if=/dev/zero of=$diskRoot1 bs=1M count=32
    dd if=/dev/zero of=$diskRoot2 bs=1M count=32
    dd if=/dev/zero of=$diskSwap bs=1M count=32
    dd if=/dev/zero of=$diskData bs=1M count=32
    badblocks -swf -b 1048576 -t ${backgroundPattern} ${disk} 16 0

    sync
    sleep 2

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

    sync
    sleep 1

    #blocksize 65536 is required by the hardware, you won't be able to mount if different.
    mkfs.ext4 -b 65536 -m 0 $diskData

    echo
    read -p "destroying was done, would you like to continue with installation? [y] " -n 1
    echo -e
    if ! [[ $REPLY =~ ^[Yy]$ ]]; then
        exit 1;
    fi
fi

#write the image to the raid disk
echo
sync
mdadm --create $rootfsRaid --verbose --metadata=0.9 --raid-devices=2 --level=raid1 --run $diskRoot1 missing
mdadm --wait $rootfsRaid
sync
sleep 2
mkfs.ext3 -c -b 4096 $rootfsRaid
sync
sleep 2

mdadm $rootfsRaid --add --verbose $diskRoot2
echo
echo -n "synchronize raid... "
sleep 2
mdadm --wait $rootfsRaid
sync
echo -e "done\n"
echo "copying image to disk... "
dd if=$image_img of=$rootfsRaid
mount $rootfsRaid $rootfsMount
cp $rootfsMount/usr/local/share/bootmd0.scr $rootfsMount/boot/boot.scr
echo "enabled" > $rootfsMount/etc/nas/service_startup/ssh
sync
sync
sync
umount $rootfsMount
rmdir $rootfsMount
mdadm --stop $rootfsRaid
./swap $diskRoot1
./swap $diskRoot2
rm ./swap

echo
echo "all done! device should be debricked!"
echo