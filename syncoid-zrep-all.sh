#!/bin/bash

export PATH="/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
echo "BEGIN: `date "+%Y-%m-%d %H:%M:%S"`"

confdir="/tank/etc"
conffile="$confdir/zrep.conf"

for i in `cat $conffile`;do
	echo ===== $i =====
	syncoid-zrep.sh $i
	echo
done

echo "END: `date "+%Y-%m-%d %H:%M:%S"`"
