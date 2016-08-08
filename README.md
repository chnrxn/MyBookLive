MyBookLive
==========

Recovery scripts for Western Digital MyBookLive NAS.

## Firmware Status Page

http://www.wdc.com/wdproducts/updates/?family=wdfmb_live

## Automatic Download

Just run `python download.py` to get the current latest firmware as shown in the firmware status page. A file of the form `apnc-024310-048-20150507.deb` should be downloaded in the current directory.

## Link to check for firmware updates

http://websupport.wdc.com/firmware/list.asp?type=AP1NC&fw=01.02.01

## Latest firmware links

My Book Live Firmware Version 02.43.10 - 048 (6/22/2015)
* http://download.wdc.com/nas/apnc-024309-038-20141208.deb

My Book Live Firmware Version 02.43.09 - 038 (1/27/2015)
* http://download.wdc.com/nas/apnc-024310-048-20150507.deb

## Crosstool

context contains a Dockerfile and Makefile that creates a CentOS-based
image to build a crosstools-ng compiler.

Use the profile _powerpc-405-linux-gnu_ to build a toolchain for MyBook Live's architecture.

## Reference

http://mybookworld.wikidot.com/forum/t-558327/previous-firmware-download-links-for-wd-mbl

http://www.schwabenlan.de/en/blog/2016/02/17/upgrading-to-jessie-on-mybooklive