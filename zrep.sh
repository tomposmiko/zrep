#!/bin/bash
# shellcheck disable=SC2002

set -euo pipefail

PATH="/root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

DATE=$(date +"%Y-%m-%d--%H")

ARGS_SYNCOID=()
DATASET_ZREP="tank/zrep"
DIR_CONFIG="/etc/zrep"
HOST_IN_PATH=0
FILE_CONFIG="$DIR_CONFIG/zrep.conf"
FREQ="daily"
LIST_SNAPSHOTS="false"
PARAM_SOURCE=""
SSH_OPTS=()

f_check_arg() {
    local arg="$1"
    local comment="$2"

    if [ -z "$comment" ];
        then
            local comment="UNKNOWN"
    fi

    if [ -z "$arg" ];
        then
            f_say_fail "Missing argument: '${comment}'!"

            exit 1
    fi
}

f_check_interactive() {
    if [ -t 0 ]
        then
            export INTERACTIVE="true"
        else
            export INTERACTIVE="false"
    fi
}

f_list_snapshots() {
    if [ "$LIST_SNAPSHOTS" == "true" ];
        then
            zfs list -t all -r "${DATASET_ZREP}/${VM_NAME}"

            exit $?
    fi
}

f_process_args() {
    # Exit if no arguments
    (( $# )) || f_usage

    local param

    while [ "$#" -gt "0" ]; do
        case "$1" in
            -c|--conf)
                param=$2
                f_check_arg "$param" "config file"
                FILE_CONFIG="$param"
                shift 2
        ;;

            -s|--source)
                param="$2"
                f_check_arg "$param" "source definition"
                PARAM_SOURCE="$param"
                shift 2
        ;;

            -f|--freq)
                param="$2"
                f_check_arg "$param" "frequency"
                FREQ="$param"
                shift 2
         ;;

            -b|--bwlimit)
                param="$2"
                f_check_arg "$param" "bandwidth limit"
                ARGS_SYNCOID+=("--target-bwlimit=${param}")
                shift 2
         ;;

            -E|--extended-vault)
                HOST_IN_PATH=1
                shift 1
         ;;

            -l|--list)
                param="$2"
                f_check_arg "$param" "source definition"
                PARAM_SOURCE="$param"
                LIST_SNAPSHOTS="true"
                shift 2
         ;;

            -q|--quiet)
                ARGS_SYNCOID+=("--quiet")
                shift 1
        ;;

            --debug)
                ARGS_SYNCOID+=("--debug")
                shift 1
        ;;

            *)
                f_usage
        ;;
        esac
    done
}

f_process_source_row() {
    local IFS

    IFS=":"

    # shellcheck disable=SC2086
    set $FULL_SOURCE_ROW

    SOURCE_HOST="$1"
    VM_NAME="$2"
    VIRT_TYPE="$3"
}

f_pull_snapshots() {
    if [[ "$VIRT_TYPE" =~ lxd-* ]];
        then
            ssh "syncoid-backup@${SOURCE_HOST}" lxc snapshot "$VM_NAME" zas-"${FREQ}-${DATE}" || true
        else
            ssh "syncoid-backup@${SOURCE_HOST}" sudo zfs snapshot -r "${REMOTE_ZFS_PATH}/${VM_NAME}@zas-${FREQ}-${DATE}" || true
    fi

    syncoid -r "${SSH_OPTS[@]}" "${ARGS_SYNCOID[@]}" "syncoid-backup@${SOURCE_HOST}:${REMOTE_ZFS_PATH}/${VM_NAME}" "${DATASET_ZREP}/${VM_NAME}"
}

f_say_fail() {
    f_check_arg "$1" "fail message"

    echo -ne "${COLOR_RED}${1}"
    echo -e "$COLOR_NO"

    exit 1
}

f_say_info() {
    f_check_arg "$1" "info message"

    echo -ne "$1"
    echo -e "$COLOR_NO"
}

f_set_colors() {
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

f_set_hostname_in_path() {
    if [ "$HOST_IN_PATH" -eq 1 ];
        then
            DATASET_ZREP="${DATASET_ZREP}/${SOURCE_HOST}"

            local dataset_type

            dataset_type=$( zfs get type -H -o value "$DATASET_ZREP" 2> /dev/null || true )

            if [ ! "$dataset_type" == "filesystem" ];
                then
                    f_say_info "Creating destination path: ${DATASET_ZREP}"

                    if ( ! zfs create "${DATASET_ZREP}" );
                        then
                            f_say_fail "Cannot create path: ${DATASET_ZREP}!"
                    fi
            fi
    fi
}

f_set_remote_zfs_path() {
    case "$VIRT_TYPE" in
        lxd-ct)
            REMOTE_ZFS_PATH="lxd/containers"
        ;;

        libvirt)
            REMOTE_ZFS_PATH="kvm"
        ;;

        lxd-kvm)
            REMOTE_ZFS_PATH="lxd/virtual-machines"
        ;;

        *)
            say "Unknown VIRT_TYPE: ${VIRT_TYPE}"

            exit 1
    esac

    export REMOTE_ZFS_PATH="tank/${REMOTE_ZFS_PATH}"
}

f_uncolorize() {
    # https://github.com/maxtsepkov/bash_colors/blob/master/bash_colors.sh
    sed -r "s/\x1B\[([0-9]{1,3}((;[0-9]{1,3})*)?)?[m|K]//g"
}

f_usage() {
  echo "Usage:"
  echo "    $0 -s <source> [-c <config file>] [--bwlimit <limit>] [--quiet|--debug] [--force]"
  echo
  echo "        -c                <config file>"
  echo "        -s|--source       <source host>:<VM>:<lxc|lxd-ct|lxd-kvm|libvirt>"
  echo "        -f|--freq         hourly|daily|weekly|monthly"
  echo "        -b|--bwlimit      <limit k|m|g|t>"
  echo "        -q|--quiet"
  echo "        --debug"
  echo "        --force"
  echo

  exit 1
}

f_validate_config_path() {
    if [ ! -f "$FILE_CONFIG" ];
        then
            f_say_fail "Config file does not exist: '$FILE_CONFIG'"
    fi

}

f_validate_dataset_zrep() {
    local dataset_type

    dataset_type=$( zfs get type -H -o value "$DATASET_ZREP" 2> /dev/null )

    if [ ! "$dataset_type" == "filesystem" ];
        then
            f_say_fail "Missing root dataset: ('$DATASET_ZREP')"
    fi
}

f_validate_debug_quiet() {
    f_check_arg "${@}" "full parameter list"

    if [[ "${*}" =~ --debug ]] && [[ "${*}" =~ --quiet|-q ]];
        then
            f_say_fail "The '--debug' and the '-q|--quiet' switches are mutually exclusive"
    fi
}

f_validate_freq() {
    if [[ ! "$FREQ" =~ hourly|daily|weekly|monthly ]];
        then
            f_say_fail "The frequency parameter is wrong: '${FREQ}'"
    fi
}

f_validate_number_of_sources() {
    f_check_arg "$1" "source entry to check"

    number_of_sources=$( cat "$FILE_CONFIG" | grep -v ^\# | grep -c "$1" )

    if [ "$number_of_sources" -eq 1 ];
        then
            FULL_SOURCE_ROW=$( grep "$1" "$FILE_CONFIG" )

        else
            echo "Exactly one source entry must exist, but '${number_of_sources}' were found."

            exit 1
    fi
}

f_validate_source_format() {
    # Is the source parameter a short or a full one?
    if ( echo "$PARAM_SOURCE" | grep -qE "^[A-Za-z0-9\.-]+:[A-Za-z0-9\.-]+:(lxc|lxd-ct|lxd-kvm|libvirt)$" );
        then
            f_validate_number_of_sources "$PARAM_SOURCE"

        elif ( echo "$PARAM_SOURCE" | grep -qE "^[A-Za-z0-9\.-]+$" ); then
            f_validate_number_of_sources ":$PARAM_SOURCE:"

        else
            f_say_fail "Wrong format of the source parameter"
    fi
}

f_validate_source_list() {
    f_check_arg "${@}" "full list parameter list"

    if [[ "${*}" =~ --list|-l ]] && [[ "${*}" =~ --source|-s ]];
        then
            f_say_fail "The '-s|--source' and the '-l|--list' switches are mutually exclusive"
    fi
}

f_check_interactive
f_set_colors
f_process_args "${@}"
f_validate_dataset_zrep
f_validate_debug_quiet "${@}"
f_validate_freq
f_validate_source_format
f_process_source_row
f_set_hostname_in_path
f_set_remote_zfs_path
f_list_snapshots
f_pull_snapshots
