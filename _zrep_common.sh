#!/bin/bash
# shellcheck disable=SC2002,SC1091

set -e

. "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")/_common.sh"

ARGS_SYNCOID=()
DATASET_ZREP="tank/zrep"
DIR_CONFIG="/etc/zrep"
FILE_CONFIG="$DIR_CONFIG/zrep.conf"
FREQ="daily"
SSH_OPTS=()

f_validate_config_path() {
    if [ ! -f "$FILE_CONFIG" ];
        then
            fc_say_fail "Config file does not exist: '$FILE_CONFIG'"
    fi

}

f_validate_freq() {
    if [[ ! "$FREQ" =~ hourly|daily|weekly|monthly ]];
        then
            fc_say_fail "The frequency parameter is wrong: '${FREQ}'"
    fi
}
