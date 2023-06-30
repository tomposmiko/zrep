#!/bin/bash
# shellcheck disable=SC2002,SC1091

set -e

. "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")/_common.sh"

ARGS_SYNCOID=()
DATASET_ZREP="tank/zrep"
DATE=$(date +"%Y-%m-%d--%H")
DIR_CONFIG="/etc/zrep"
HOST_IN_PATH=0
FILE_CONFIG="$DIR_CONFIG/zrep.conf"
FREQ="daily"
PARAM_SOURCE=""
SSH_OPTS=()

f_process_source_row() {
    local IFS

    IFS=":"

    # shellcheck disable=SC2086
    set $FULL_SOURCE_ROW

    SOURCE_HOST="$1"
    VM_NAME="$2"
    VIRT_TYPE="$3"
}

f_validate_config_path() {
    if [ ! -f "$FILE_CONFIG" ];
        then
            fc_say_fail "Config file does not exist: '$FILE_CONFIG'"
    fi

}

f_validate_debug_quiet() {
    fc_check_arg "${@}" "full parameter list"

    if [[ "${*}" =~ --debug ]] && [[ "${*}" =~ --quiet|-q ]];
        then
            fc_say_fail "The '--debug' and the '-q|--quiet' switches are mutually exclusive"
    fi
}

f_validate_freq() {
    if [[ ! "$FREQ" =~ hourly|daily|weekly|monthly ]];
        then
            fc_say_fail "The frequency parameter is wrong: '${FREQ}'"
    fi
}
