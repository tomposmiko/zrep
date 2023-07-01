#!/bin/bash

set -e

. "$( dirname "$( readlink /proc/$$/fd/255 2>/dev/null )" )/_common.sh"

. "$( dirname "$( readlink /proc/$$/fd/255 2>/dev/null )" )/_zrep_common.sh"

f_destroy_snaps() {
    fc_check_arg "${@}" "Full argument list"

    local IFS=$'\n'
    local snap_string
    local snap_path

    for snap_string in "${@}"; do

        # shellcheck disable=SC2013
        for snap_path in $( grep "$snap_string" "$SNAP_LIST_ALL" ); do
            fc_say_info "zfs destroy ${snap_path}"

            zfs destroy "${snap_path}"
        done
    done
}

f_list_all_snaps() {
    zfs list -t snap -r -H -o name -s name "$DATASET_ZREP" | tee "$SNAP_LIST_ALL" > /dev/null
}

fc_temp_file_create "SNAP_LIST_ALL"

f_list_all_snaps

f_destroy_snaps "${@}"

fc_temp_file_remove "$SNAP_LIST_ALL"
