test -v BTRFS_LIB && return || readonly BTRFS_LIB="$(realpath "$BASH_SOURCE")"

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
