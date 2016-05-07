#!/bin/bash

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

date=`date +"%Y-%m-%d"`

confdir="/tank/etc"
conffile="$confdir/zrep.conf"

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


# usage
if [ -z $1 ];then
	echo
	echo "No script parameter added!"
	echo "One of the following is needed:"
	echo 
	echo "	<source host>:<VM>:<lxc|lxd|kvm>"
	echo
	exit 1
fi


# whether it's a short or long parameter for the source?
if echo $1|grep -q : ;
	then
		if echo $1 | egrep "[A-Za-z0-9][\.A-Za-z0-9-]+:[A-Za-z0-9][A-Za-z0-9-]+:(lxc|lxd|kvm)";
			then
				full_conf_entry=1
			else
				echo "Wrong backup config!"
				exit 1
		fi
				
	else
		if echo $1 | egrep "[A-Za-z0-9][A-Za-z0-9-]+"
			then
				full_conf_entry=0
			else
				echo "Wrong backup config!"
				exit 1
		fi
fi


# is the matching pattern unique?
if [ $full_conf_entry -eq 0 ];
	then
		same_entries_in_config=`awk -F: '/'":$1"':/ { print $1":"$2":"$3 }' $conffile|wc -l`
	else
		same_entries_in_config=`grep -c $1 $conffile`
fi
if ! [ $same_entries_in_config -eq 1 ];
	then
		echo "Exactly one source entry must exist. Currently $same_entries_in_config found."
		exit 1
fi


# if it's not a full definition, rerun the script with that
if [ $full_conf_entry -eq 0 ];
	then
		conf_entry=`awk -F: '/'":$1"':/ { print $1":"$2":"$3 }' $conffile`
		$0 $conf_entry
fi


# if it's a full definition, we don't need to to any special thing
if [ $full_conf_entry -eq 1 ];
	then
		s_host=`echo $1 | cut -f1 -d:`
		vm=`echo $1 | cut -f2 -d:`
		virttype=`echo $1 | cut -f3 -d:`
		if [ "$virttype" = lxd ];
			then
				zfs_path=lxd/containers

			else zfs_path=$virttype
		fi
fi

# ssh tuning
# https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Security_Guide/sect-Security_Guide-Encryption-OpenSSL_Intel_AES-NI_Engine.html
if [ x`grep -m1 -w -o aes /proc/cpuinfo` == x"aes" ];
	then
		ssh_opts="--ssh-cipher=aes256-gcm@openssh.com"
fi


f_zrep(){
	if [ -z $1 ];then
		echo "No VM defined"
		exit 1
	fi

	# create destination zfs path recursively
	if ! zfs list -o name tank/zrep/$virttype/$s_host > /dev/null 2>&1;
		then
			zfs create tank/zrep/$virttype/$s_host
			zfs create tank/zrep/$virttype/$s_host/$vm
		else
			if ! zfs list -o name tank/zrep/$virttype/$s_host/$vm > /dev/null 2>&1;
				then
					zfs create tank/zrep/$virttype/$s_host/$vm
			fi
	fi
	# can be readded with criu 1.9+
	#ssh $s_host lxc snapshot $vm zas_${date}
        if [ "$virttype" = lxd ];
            then
				ssh lxd-backup@$s_host lxc snapshot $vm zas_${date}
            else
				ssh zfs@$s_host zfs snapshot -r tank/$virttype/$vm@zas-${date}
        fi

	zreplicate $ssh_opts --no-replication-stream $args zfs@$s_host:tank/$zfs_path/$vm tank/zrep/$virttype/$s_host/$vm
}



f_zrep $1
