#!/bin/bash

export PATH="/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

date=`date +"%Y-%m-%d"`

confdir="/tank/etc"
conffile="$confdir/zrep.conf"
dataset=$1

if /usr/bin/tty > /dev/null;
    then
        quiet=0
        interactive=1
		console=1
	else
		console=0
fi

# https://github.com/maxtsepkov/bash_colors/blob/master/bash_colors.sh
uncolorize () { sed -r "s/\x1B\[([0-9]{1,3}((;[0-9]{1,3})*)?)?[m|K]//g"; }
if [[ $interactive -eq 1 ]]
   then say() { echo -ne $1;echo -e $nocolor; }
                # Colors, yo!
                green="\e[1;32m"
                red="\e[1;31m"
                blue="\e[1;34m"
                purple="\e[1;35m"
                cyan="\e[1;36m"
                nocolor="\e[0m"
   else
                # do nothing
                say() { true; }
fi

if [ $console -eq 1 ];
 then
	args="-o --create-destination"
fi


if [ -z $dataset ];then
	echo "No dataset defined"
	exit 1
fi

# ssh tuning
# https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Security_Guide/sect-Security_Guide-Encryption-OpenSSL_Intel_AES-NI_Engine.html
if [ x`grep -m1 -w -o aes /proc/cpuinfo` == x"aes" ];
    then
        ssh_opts="--ssh-cipher=aes128-cbc"
fi


f_zrep(){
	if [ -z $1 ];then
		echo "No dataset defined"
		exit 1
	fi
	ssh zfs@$s_host zfs snapshot -r tank/$virttype/$dataset@zas-${date}
	zreplicate $ssh_opts --no-replication-stream $args zfs@$s_host:tank/$virttype/$dataset tank/zrep/$dataset
}


rows_number_with_dataset=`grep -c ^${dataset}: $conffile`
if ! [ $rows_number_with_dataset -eq 1 ];then
	echo "Pattern not unique: $rows_number_with_dataset"
	exit 1
fi

virttype=`awk -F: '/^'"$dataset"':/ { print $2 }' $conffile`
s_host=`awk -F: '/^'"$dataset"':/ { print $3 }' $conffile`

if [ -z $s_host ];then
	echo "No source host found!"
	exit 1
fi

if [ -z $virttype ];then
	echo "No virttype found!"
	exit 1
fi


f_zrep $dataset
