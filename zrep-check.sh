#!/bin/bash

export PATH="/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# shellcheck disable=SC1091
#. /etc/zabbix/userparams/config

export slack_url_post='https://slack.com/api/chat.postMessage'
# https://api.slack.com/authentication/oauth-v2
#slack_token='<Bot User OAuth Token>'
#slack_channel='<channel>'
# shellcheck disable=SC1091
. /etc/slack-notification.conf

f_check_switch_param(){
  if echo x"$1" |grep -q ^x$;
   then
     echo "Missing argument!"
     exit 1
  fi
}


f_usage(){
  echo "Usage:"
  echo " $0 -d <days> -w <days> [ --debug ] [ --noop ]"
  echo " $0 --generate-debug-txt"
  echo " $0 -h|--help"
  echo
  echo "-d|--daily <days>      set the alert limit for the last daily snapshot"
  echo "-w|--weekly <days>     set the alert limit for the last weekly snapshot"
  echo "--generate-debug-txt   generate /root/zrep-check-debug.txt for speed up debugging"
  exit 1
}

# Exit if no arguments!
(( $# )) || { f_usage; exit 1; }

while [ "$#" -gt "0" ]; do
  case "$1" in
    -d|--daily)
      PARAM=$2
      f_check_switch_param "$PARAM"
      limit_daily="$PARAM"
      shift 2
    ;;

    -w|--weekly)
      PARAM="$2"
      f_check_switch_param "$PARAM"
      limit_weekly="$PARAM"
      shift 2
    ;;

    --noop)
      noop_mode=1
      shift 1
    ;;

    --debug)
      debug_mode=1
      shift 1
    ;;

    --generate-debug-txt)
      generate_debug_txt=1
      shift 1
    ;;

    *)
      f_usage
    ;;

   esac
done

date_today=$(date "+%Y-%m-%d")


f_slack_post() {
  slack_text="$1"
  # shellcheck disable=SC2154
  curl -d "text=$slack_text" -d "channel=$slack_channel" -d "token=$slack_token" -s -X POST $slack_url_post > /dev/null
}

f_date_to_epoch () {
  date --utc --date "$1" +%s
}

f_date_diff (){
  case "$1" in
    -s)   sec=1;      shift;;
    -m)   sec=60;     shift;;
    -h)   sec=3600;   shift;;
    -d)   sec=86400;  shift;;
    *)    sec=86400;;
  esac
  dte1=$(f_date_to_epoch "$1")
  dte2=$(f_date_to_epoch "$2")
  diffSec=$((dte2-dte1))
  echo $((diffSec/sec))
}


if [ -n "$generate_debug_txt" ];
  then
    echo -n "Generating /root/zrep-check-debug.txt for debugging purposes... "
    zfs list -t all -r tank/zrep -o name -H | grep -v "^tank/zrep$" | tee "/root/zrep-check-debug.txt" > /dev/null
    echo "done."
    exit 0
fi

if [ -z "$debug_mode" ];
  then
    snap_list_file=$(mktemp /tmp/snap_list_file.XXXX)
    zfs list -t all -r tank/zrep -o name -H | grep -v "^tank/zrep$" | tee "$snap_list_file" > /dev/null
  else
    snap_list_file='/root/zrep-check-debug.txt'
fi

dataset_list=$(grep -v @ "$snap_list_file")

f_check_late(){
  dataset="$1"
  freq="$2"
  days_limit="$3"

  snap_last_item=$(grep "${dataset}@" "$snap_list_file" | grep -o "zas-${freq}-.*" | tail -1)
  if [ "$snap_last_item" = "" ];
    then
      msg="DEBUG: !!! WARNING !!!: *${dataset}* has *NO VALID '${freq}' SNAPSHOT*!"
      if [ -z "$debug_mode" ];
        then
          echo "$msg"
          [[ -z "$noop_mode" ]] && f_slack_post "$msg"
        else
          echo "DEBUG: $msg"
          [[ -z "$noop_mode" ]] && f_slack_post "DEBUG: $msg"
      fi
      return 0
 fi
  date_last_snap=$(echo "$snap_last_item" | grep -o "202[0-9]-[0-9][0-9]-[0-9][0-9]")
  days_diff=$(f_date_diff -d "$date_last_snap" "$date_today")

  if (( "$days_diff" > "$days_limit" ));
    then
      msg="Time spent since the last *${freq}* backup of *${dataset}*: *${days_diff} days*"
      if [ -z "$debug_mode" ];
        then
          echo "$msg"
          [[ -z "$noop_mode" ]] && f_slack_post "$msg"
        else
          echo "DEBUG: $msg"
          [[ -z "$noop_mode" ]] && f_slack_post "DEBUG: $msg"
      fi
  fi
}

if [ "$limit_daily" ];
  then
    for d in $dataset_list;do
      f_check_late "$d" daily "$limit_daily";
    done
fi

if [ "$limit_weekly" ];
  then
    for d in $dataset_list;do
      f_check_late "$d" weekly "$limit_weekly";
    done
fi

[[ -z "$debug_mode" ]] && rm -f "$snap_list_file"
