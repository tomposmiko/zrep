#!/bin/bash

set -e

# shellcheck source=_common.sh
. "$( dirname "$( readlink /proc/$$/fd/255 2>/dev/null )" )/_common.sh"

# shellcheck source=_zrep_common.sh
. "$( dirname "$( readlink /proc/$$/fd/255 2>/dev/null )" )/_zrep_common.sh"

f_list_all_snaps() {
    zfs list -t snap -r -H tank -o name -s name tank/lxd/containers | grep @snapshot- | sed -e 's@tank/lxd/containers/@@' -e 's,@snapshot-,/,'

}

f_destroy_snaps() {
    f_check_arg "${@}" "Full argument list"

    local IFS=$'\n'
    local snap_string
    local snap_name

    for snap_string in "${@}"; do
        # shellcheck disable=SC2013
        for snap_name in $( grep "$snap_string" "$SNAP_LIST_ALL" ); do
            f_say_info "lxc delete ${snap_name}"

            lxc delete "${snap_name}"
        done
    done
}

fc_temp_file_create "SNAP_LIST_ALL"

f_list_all_snaps > "$SNAP_LIST_ALL"

fc_temp_file_remove "$SNAP_LIST_ALL"
