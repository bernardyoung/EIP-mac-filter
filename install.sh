#!/bin/bash
path="/var/lib/zstack/EIP-mac-filter"
configfile="ebtables.conf"
configfilepath=$path"/"$configfile
mkdir -p $path
touch $configfilepath
cp ./mac-filter-create.sh $path
echo $path"/"mac-filter-create.sh >> /etc/rc.d/rc.local
