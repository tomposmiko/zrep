#!/bin/bash
# shellcheck disable=SC1091

set -e

. "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")/_common.sh"

. "$(dirname "$(readlink /proc/$$/fd/255 2>/dev/null)")/_zrep_common.sh"

f_process_args() {
    # Exit if no arguments!
    (( "$#" )) || f_usage

    while [ "$#" -gt "0" ]; do
        case "$1" in
            -c|--conf)
                PARAM=$2
                fc_check_arg "$PARAM" "config file"
                conffile="$PARAM"
                shift 2
            ;;

            -f|--freq)
                PARAM=$2
                fc_check_arg "$PARAM" "frequency"
                FREQ="$PARAM"
                shift 2
            ;;

            *)
                f_usage
            ;;
        esac
    done
}

f_usage(){
    echo "Usage:"
    echo "  $0 [-c conffile]"
    echo
    echo "      -c|--conffile     <config file>"
    echo "      -f|--freq         <frequency>"
    echo

    exit 1
}

f_process_args "${@}"
f_validate_config_path
f_validate_freq

fc_say_info "BEGIN: $(date "+%Y-%m-%d %H:%M")"


for source_item in $(grep -v "^#" "$conffile"); do
    DATE=$(date "+%Y-%m-%d %H:%M:%S")
    echo "${DATE} - $source_item"
    zrep.sh --quiet -s "$source_item" -f "$FREQ" -c "$conffile" || true
done

fc_say_info "FINISH: $(date "+%Y-%m-%d %H:%M")"
