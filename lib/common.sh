test -v COMMON_LIB && return || readonly COMMON_LIB="$(realpath $BASH_SOURCE)"

set -o nounset -o pipefail -o errexit -o errtrace -o functrace

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

older-than() {
    local -r file="$1" max_age="$2"
    local -i last_update oldest_allowed
    if [ -e "$file" ]; then
        last_update=$(date -r "$file" +%s)
        oldest_allowed=$(date -d "now - $max_age" +%s)
        (( last_update < oldest_allowed ))
    else
        true
    fi
}

mount-dir() {
    local -r device="$1" dir="$2" options="${3:+-o $3}"
    [ -d $dir ] || { mkdir -v $dir && CLEANUPS+=("rmdir -v $dir"); }
    mount -v $options $device $dir
    CLEANUPS+=("umount -vd $dir")
}

umount-if-mounted() {
    local -r target="$1"
    if mountpoint -q "$target"; then umount -v "$target"; fi
}

bind-file() {
    local -r source="$1" target="$2"
    [ -f "$source" ] || return 0
    if ! [ -f "$target" ]; then
        touch "$target"
        CLEANUPS+=("rm -v $target")
    fi
    mount -v --bind -o ro "$source" "$target"
    CLEANUPS+=("umount -v $target")
}

bind-dir() {
    local -r source="$1" target="$2" options="${3:+-o $3}"
    [ -d "$source" ] || return 0
    if ! [ -d "$target" ]; then
        mkdir -v "$target"
        CLEANUPS+=("rmdir -v $target")
    fi
    mount -v --bind $options "$source" "$target"
    CLEANUPS+=("umount -v $target")
}

make-temp-dir() {
    local -r dir=$(mktemp -dp '' ${SCRIPT_NAME}-XXX)
    CLEANUPS+=("rmdir -v $dir")
    echo "$dir"
}
