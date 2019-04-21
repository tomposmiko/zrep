#!/bin/bash

export PATH="/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

confdir="/etc/zrep"
conffile="$confdir/zrep.conf"

echo "BEGIN: `date "+%Y-%m-%d %H:%M:%S"`"
for i in `grep -v ^\# $conffile`;do
	echo "==== $i ===="
	zrep.sh -s $i
done

echo "END: `date "+%Y-%m-%d %H:%M:%S"`"
