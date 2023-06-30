#!/bin/bash

# The prefix 'fc_' refers to 'function common'


set -euo pipefail

PATH="/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

fc_check_arg() {
    local arg="$1"
    local comment="$2"

    if [ -z "$comment" ];
        then
            local comment="UNKNOWN"
    fi

    if [ -z "$arg" ];
        then
            fc_say_fail "Missing argument: '${comment}'!"

            exit 1
    fi
}

fc_check_interactive() {
    if [ -t 0 ]
        then
            export INTERACTIVE="true"
        else
            export INTERACTIVE="false"
    fi
}

fc_say_fail() {
    fc_check_arg "$1" "fail message"

    echo -ne "${COLOR_RED}${1}"
    echo -e "$COLOR_NO"

    exit 1
}

fc_say_info() {
    fc_check_arg "$1" "info message"

    echo -ne "$1"
    echo -e "$COLOR_NO"
}

fc_set_colors() {
    if [ "$INTERACTIVE" == "true" ];
        then
            export COLOR_BLUE="\e[1;34m"
            export COLOR_CYAN="\e[1;36m"
            export COLOR_GREEN="\e[1;32m"
            export COLOR_PURPLE="\e[1;35m"
            export COLOR_RED="\e[1;31m"
            export COLOR_NO="\e[0m"
        else
            export COLOR_BLUE=""
            export COLOR_CYAN=""
            export COLOR_GREEN=""
            export COLOR_PURPLE=""
            export COLOR_RED=""
            export COLOR_NO=""
    fi

}

fc_uncolorize() {
    # https://github.com/maxtsepkov/bash_colors/blob/master/bash_colors.sh
    sed -r "s/\x1B\[([0-9]{1,3}((;[0-9]{1,3})*)?)?[m|K]//g"
}

fc_check_interactive
fc_set_colors
