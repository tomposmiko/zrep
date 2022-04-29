#!/bin/bash

interactive=0
if /usr/bin/tty > /dev/null;
  then
    interactive=1
fi

# https://github.com/maxtsepkov/bash_colors/blob/master/bash_colors.sh
uncolorize () { sed -r "s/\x1B\[([0-9]{1,3}((;[0-9]{1,3})*)?)?[m|K]//g"; }
if [ $interactive -eq 1 ]
  then say() { echo -ne "$1";echo -e "$nocolor"; }
    # Colors, yo!
    green="\e[1;32m"
    # shellcheck disable=SC2034
    red="\e[1;31m"
    # shellcheck disable=SC2034
    blue="\e[1;34m"
    # shellcheck disable=SC2034
    purple="\e[1;35m"
    # shellcheck disable=SC2034
    cyan="\e[1;36m"
    nocolor="\e[0m"
  else
    # do nothing
    say() { true; }
fi

export PATH="/root/bin:/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

dataset_list=$(mktemp /tmp/datasets.XXXXXX)
zfs list -t snap -r -H -o name -s name tank/zrep | tee "$dataset_list" > /dev/null

for snap in "$@";do
  # ugly solution, should be written as recommended
  # shellcheck disable=SC2013
  for dataset_path in $(grep "$snap" "$dataset_list");do
    say "$green zfs destroy ${dataset_path}"
    zfs destroy "${dataset_path}"
  done
done

rm "${dataset_list}"
