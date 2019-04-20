#!/bin/bash

export PATH="/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

date=`date +"%Y-%m-%d--%H"`

confdir="/etc/zrep"
conffile="$confdir/zrep.conf"
zrepds="zrep"
syncoid_args=""
norollback="--no-rollback"
quiet="0"
debug="0"
sourcedef=""

if /usr/bin/tty > /dev/null;
    then
        console=1
        interactive=1
    else
        console=0
fi

# https://github.com/maxtsepkov/bash_colors/blob/master/bash_colors.sh
uncolorize () { sed -r "s/\x1B\[([0-9]{1,3}((;[0-9]{1,3})*)?)?[m|K]//g"; }
if [[ "$interactive" -eq 1 ]]
   then say() { echo -ne $1;echo -e "$nocolor"; }
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

f_check_switch_param(){
    if echo x"$1" |grep -q ^x$;
	    then
            say "$red Missing argument!"
            exit 1
    fi
}

f_usage(){
    echo "Usage:"
    echo " $0 -s source [-c conffile] [--quiet|--debug] [--force]"
    echo
    echo "  -c|--conffile     <config file>"
    echo "  -s|--source       <source host>:<VM>:<lxc|lxd|kvm>"
    echo "  -q|--quiet"
    echo "  --force"
    echo "  --debug"
    echo
    exit 1
}


# Exit if no arguments!
let $# || { f_usage; exit 1; }

while [ "$#" -gt "0" ]; do
  case "$1" in
    -c|--conf)
        PARAM=$2
        f_check_switch_param "$PARAM"
        conffile="$PARAM"
        shift 2
    ;;

    -s|--source)
        PARAM="$2"
        f_check_switch_param "$PARAM"
        sourcedef="$PARAM"
        shift 2
     ;;

    -l|--list)
        PARAM="$2"
        f_check_switch_param "$PARAM"
        dst_to_list="$PARAM"
        shift 2
     ;;

     --force)
        norollback=""
        shift 1
     ;;

    -q|--quiet)
        quiet=1
        shift 1
    ;;

    --debug)
        debug=1
        shift 1
    ;;

    *)
        f_usage
    ;;
   esac
done


# syncoid args debug and quiet should be mutually exclusive
if [ "$quiet" -eq 1 ];
    then
       syncoid_args="--quiet"
fi

if [ "$debug" -eq 1 ];
    then
       syncoid_args="--debug"
fi

# is the source a long or short paramater?
if echo "$sourcedef" | grep -q : ;
    then
        if echo "$sourcedef" | egrep -q "[A-Za-z0-9][\.A-Za-z0-9-]+:[A-Za-z0-9][A-Za-z0-9-]+:(lxc|lxd|kvm)";
            then
                full_conf_entry=1
            else
                echo "Wrong backup config!"
                exit 1
        fi

    else
        if echo "$sourcedef" | egrep -q "[A-Za-z0-9][A-Za-z0-9-]+"
            then
                full_conf_entry=0
            else
                echo "Wrong backup config!"
                exit 1
        fi
fi


# is the matching pattern unique?
if [ "$full_conf_entry" -eq 0 ];
    then
        same_entries_in_config=`awk -F: '/'":$sourcedef"':/ { print $1":"$2":"$3 }' "$conffile" | wc -l`
    else
        same_entries_in_config=`grep -c "$sourcedef" "$conffile"`
fi
if ! [ "$same_entries_in_config" -eq 1 ];
    then
        echo "Exactly one source entry must exist. Currently $same_entries_in_config found."
        exit 1
fi


# if it's not a full (short) line definition, rerun the script with the full one
if [ $full_conf_entry -eq 0 ];
    then
        conf_entry=`awk -F: '/'":$sourcedef"':/ { print $1":"$2":"$3 }' $conffile`
        $0 -s $conf_entry
        exit $?
fi


# if it's a full (long) line definition, we need to do nothing special
if [ $full_conf_entry -eq 1 ];
    then
        s_host=`echo "$sourcedef" | cut -f1 -d:`
        vm=`echo "$sourcedef" | cut -f2 -d:`
        virttype=`echo "$sourcedef" | cut -f3 -d:`
        if [ "$virttype" = "lxd" ];
            then
                zfs_path="lxd/containers"

            else zfs_path="$virttype"
        fi
fi

# ssh tuning
# https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Security_Guide/sect-Security_Guide-Encryption-OpenSSL_Intel_AES-NI_Engine.html
if [ x`grep -m1 -w -o aes /proc/cpuinfo` == x"aes" ];
    then
        ssh_opts="-c aes256-gcm@openssh.com"
fi


f_zrep(){
    if [ -z "$sourcedef" ];
        then
            say "$red No VM defined"
            exit 1
    fi

    if [ "$virttype" = "lxd" ];
        then
            ssh syncoid@"$s_host" "lxc snapshot $vm zas-${date}"
        else
            ssh syncoid@"$s_host" "zfs snapshot -r tank/$virttype/$vm@zas-${date}"
    fi

    syncoid -r $norollback $ssh_opts $syncoid_args syncoid@"$s_host:tank/$zfs_path/$vm" "tank/$zrepds/$vm"
}


f_zrep $1
