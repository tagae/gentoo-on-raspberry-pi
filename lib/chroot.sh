test -v CHROOT_LIB && return || readonly CHROOT_LIB="$(realpath "$BASH_SOURCE")"

: ${LIB_DIR:="$(dirname "$CHROOT_LIB")"}

bind-system-dirs() {
    mount -v --types proc /proc $ROOT/proc
    CLEANUPS+=("umount -R $ROOT/proc")

    mount -v --rbind /sys $ROOT/sys
    mount -v --make-rslave $ROOT/sys
    CLEANUPS+=("umount -R $ROOT/sys")

    mount -v --rbind /dev $ROOT/dev
    mount -v --make-rslave $ROOT/dev
    CLEANUPS+=("umount -R $ROOT/dev")
}
