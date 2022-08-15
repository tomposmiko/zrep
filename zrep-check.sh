#!/bin/bash

# shellcheck disable=SC1091
. /etc/zabbix/userparams/config

slack_url_post='https://slack.com/api/chat.postMessage'
# https://api.slack.com/authentication/oauth-v2
#slack_token='<Bot User OAuth Token>'
#slack_channel='<channel>'
. /etc/slack-notification.conf

debug_mode=0

f_slack_post() {
  slack_text="$1"
  # shellcheck disable=SC2154
  curl -d "text=$slack_text" -d "channel=$slack_channel" -d "token=$slack_token" -s -X POST $slack_url_post > /dev/null
}

displaytime1() {
  local T=$1
  local D=$((T/60/60/24))
  local H=$((T/60/60%24))
  local M=$((T/60%60))
  local S=$((T%60))
  (( "$D" > 0 )) && printf '%d days ' $D
  (( "$H" > 0 )) && printf '%d hours ' $H
  (( "$M" > 0 )) && printf '%d minutes ' $M
  (( "$D" > 0 || "$H" > 0 || "$M" > 0 )) && printf 'and '
  printf '%d seconds\n' $S
}

displaytime2() {
  local t="$1"
  local d=$((t/60/60/24))
  local h=$((t/60/60%24))
  local m=$((t/60%60))
  local s=$((t%60))

  if [[ $d -gt 0 ]];
    then
      [[ $d = 1 ]] && echo -n "$d day " || echo -n "$d days "
  fi

  if [[ $h -gt 0 ]];
    then
      [[ $h = 1 ]] && echo -n "$h hour " || echo -n "$h hours "
  fi

  if [[ $m -gt 0 ]];
    then
      [[ $m = 1 ]] && echo -n "$m minute " || echo -n "$m minutes "
  fi

  if [[ $d = 0 && $h = 0 && $m = 0 ]];
    then
      [[ $s = 1 ]] && echo -n "$s second" || echo -n "$s seconds"
  fi
  echo
}

if [ "$1" == "--debug" ];
  then
    readonly debug_mode=1
fi

# for debugging
if [ $debug_mode -eq 1 ];
  then
    snap_list_file=a.txt
  else
    snap_list_file=$(mktemp /tmp/tmp.zrep_check_snap_list.XXXX)
    zfs list -t all -r tank/zrep -o name -H | grep -v "^tank/zrep$" > "$snap_list_file"
fi

dataset_list=$(grep -v @ "$snap_list_file")

#for i in $dataset_list
f_check_late(){
  dataset="$1"
  freq="$2"
  date_late="$3"

  snap_last_item=$(grep "${dataset}@" "$snap_list_file" | grep -o "zas-${freq}-.*" | tail -1)
  snap_last_date=$(echo "$snap_last_item" | grep -o "202[0-9]-[0-9][0-9]-[0-9][0-9]")
  snap_last_epoch=$(date "+%s" -d "$snap_last_date")

  time_late_epoch=$(date -d "$date_late" +%s)
  time_difference=$(( "$snap_last_epoch" - "$time_late_epoch" ))

#date_2_days_ago=$(date -d "2 days ago" +%s)
#echo $snap_last_epoch
#echo $date_2_days_ago
#echo $[ $snap_last_epoch - $date_2_days_ago ]


  #echo "Last $freq epoch of $dataset: $snap_last_epoch"
  if [ $debug_mode -eq 1 ];
    then
      echo "Last $freq time difference of $dataset: $time_difference"
      f_slack_post "@channel Last $freq time difference of $dataset: $time_difference"

    else
      if [ "$time_difference" -le 0 ];
        then
          time_human=$(displaytime2 $time_difference)
          echo "Time spent since $freq backup of ${dataset}: $time_human"
          f_slack_post "Time spent since $freq backup of ${dataset}: $time_human"
      fi
  fi

}

for d in $dataset_list;do
  f_check_late "$d" daily "2 days ago";
done

for d in $dataset_list;do
  f_check_late "$d" weekly "8 days ago";
done

rm -f "$snap_list_file"

# zabbix_sender -z $SENDER_HOST -p $SENDER_PORT -i $TMPFILE $ZS_ARGS
