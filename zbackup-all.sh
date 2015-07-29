#!/bin/bash

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
echo "BEGIN: `date "+%Y-%m-%d %H:%M:%S"`"

confdir="/tank/etc"
conffile="$confdir/zrep.conf"

for i in `cut -f1 -d: $conffile`;do
	echo ===== $i =====
	zrep.sh $i
done

echo "END: `date "+%Y-%m-%d %H:%M:%S"`"
