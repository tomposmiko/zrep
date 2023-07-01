#!/bin/bash

set -e

# shellcheck source=_common.sh
. "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")/_common.sh"

# shellcheck source=_zrep_common.sh
. "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")/_zrep_common.sh"

f_create_temp_file() {
    SNAP_LIST_ALL=$(mktemp /tmp/datasets.XXXXXX)
}

f_destroy_snaps() {
    local IFS=$'\n'
    local snap_string
    local snap_path

    for snap_string in "${@}";do
        # shellcheck disable=SC2013
        for snap_path in $(grep "$snap_string" "$SNAP_LIST_ALL");do
            f_say_info "zfs destroy ${snap_path}"

            zfs destroy "${snap_path}"
        done
    done
}

f_list_all_snaps() {
    zfs list -t snap -r -H -o name -s name "$DATASET_ZREP" | tee "$SNAP_LIST_ALL" > /dev/null
}

f_remove_temp_file() {
    rm "$SNAP_LIST_ALL"
}

f_create_temp_file

f_list_all_snaps

f_destroy_snaps "${@}"

f_remove_temp_file
