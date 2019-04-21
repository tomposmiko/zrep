#!/bin/bash

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

if /usr/bin/tty > /dev/null;
    then
        export console=1
        interactive=1
    else
        export console=0
fi

# https://github.com/maxtsepkov/bash_colors/blob/master/bash_colors.sh
uncolorize () { sed -r "s/\x1B\[([0-9]{1,3}((;[0-9]{1,3})*)?)?[m|K]//g"; }
if [[ "$interactive" -eq 1 ]]
   then say() { echo -ne "$1";echo -e "$nocolor"; }
                # Colors, yo!
                export green="\e[1;32m"
                export red="\e[1;31m"
                export blue="\e[1;34m"
                export purple="\e[1;35m"
                export cyan="\e[1;36m"
                export nocolor="\e[0m"
   else
                # do nothing
                say() { true; }
fi

f_check_switch_param(){
    if echo x"$1" |grep -q ^x$;
        then
            say "$red" "Missing argument!"
            exit 1
    fi
}

date=`date +"%Y-%m-%d--%H"`
confdir="/etc/zrep"
#conffile="$confdir/zrep.conf"
zrepds="zrep"
custom_zrepds=""
syncoid_args=""
quiet="0"
debug="0"
sourceparam=""
to_list=0

f_usage(){
    echo "Usage:"
    echo " $0 [-c conffile]"
    echo
    echo "  -c|--conffile     <config file>"
    echo
    exit 1
}


# Exit if no arguments!
let "$#" || { f_usage; exit 1; }

while [ "$#" -gt "0" ]; do
  case "$1" in
    -c|--conf)
        PARAM=$2
        f_check_switch_param "$PARAM"
        conffile="$PARAM"
        shift 2
    ;;

    *)
        f_usage
    ;;
   esac
done

if ! [ "$conffile" ]; then
	say "$red" "!!! ERROR !!!"
	say "$red" "No config file was given!"
	exit 1
fi


echo "BEGIN: `date "+%Y-%m-%d %H:%M:%S"`"
for i in `grep -v ^\# "$conffile"`;do
	echo "==== "$i" ===="
	zrep.sh --quiet -s "$i"
done

echo "END: `date "+%Y-%m-%d %H:%M:%S"`"
