test -v MOUNT_LIB && return || readonly MOUNT_LIB="$(realpath $BASH_SOURCE)"

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
