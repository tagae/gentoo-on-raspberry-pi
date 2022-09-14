test -v RUNTIME_LIB && return || readonly RUNTIME_LIB="$(realpath $BASH_SOURCE)"

set -o nounset -o pipefail -o errexit -o errtrace -o functrace
shopt -s inherit_errexit
shopt -s nullglob

if test -v DEBUG; then
   set -o xtrace
   trap 'failed "$BASH_COMMAND" "$BASH_SOURCE" "$LINENO"' ERR
fi

trap cleanup EXIT

CLEANUPS=()

cleanup() {
    local index
    # run cleanups in reverse order
    for (( index=${#CLEANUPS[@]}-1; index >= 0; index-- )); do
        eval "${CLEANUPS[index]}"
    done
}

failed() {
    local -r command="$1" source="$2" line_number="$3"
    echo "[DEBUG] $command failed at $source:$line_number" >&2
}

die() {
    {
        case $# in
            0) cat ;;
            *) echo Error: "$@" ;;
        esac
    } >&2
    exit 1
}

source-from() {
    local -r SOURCE_DIR="$1"
    shift
    local SCRIPT SCRIPT_SOURCE
    for SCRIPT in "$@"; do
        SCRIPT_SOURCE="$SOURCE_DIR/$SCRIPT.sh"
        [ ! -f "$SCRIPT_SOURCE" ] || source "$SCRIPT_SOURCE"
    done
}
