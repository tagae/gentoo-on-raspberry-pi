test -v BTRFS_LIB && return || readonly BTRFS_LIB="$(realpath "$BASH_SOURCE")"

has_btrfs() {
    command -v btrfs > /dev/null
}

is_btrfs_subvolume() {
    local -r dir="$1"
    [ -d "$dir" ] || return 1
    [ "$(stat -f --format="%T" "$dir")" == btrfs ] || return 2
    [[ "$(stat --format="%i" "$dir")" =~ 2|256 ]] && return 0
    return 3
}

create-subvolume() {
    local -r subvol="$1"
    if ! test -d "$subvol"; then
        mkdir -vp "$(dirname "$subvol")"
        btrfs subvolume create "$subvol"
    fi
}

delete-subvolume() {
    local subvolume
    btrfs subvolume list -o "$ROOT" | awk '{print $9}' | while read subvolume; do
        local -r parent="${subvolume%%$ROOT*}"
        btrfs subvolume delete "${subvolume#$parent}"
    done
    btrfs subvolume delete "$ROOT"
}

snapshot-subvolume() {
    local opts
    local OPTIND
    while getopts :r OPTION; do
        case $OPTION in
            r) opts="-r" ;;
            \?) unknown-option ;;
        esac
    done
    shift $((OPTIND-1))
    local -r src="$1"
    local -r dest="$2"
    if ! is_btrfs_subvolume "$dest"; then
        mkdir -vp "$(dirname "$dest")"
        btrfs subvolume snapshot ${opts:-} "$src" "$dest"
    fi
}

dir-hash() {
    local -r dir="$1"
    tar c "$dir" | sha256sum
}
