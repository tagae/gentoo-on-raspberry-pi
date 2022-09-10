test -v INSTALL_LIB && return || readonly INSTALL_LIB="$(realpath "$BASH_SOURCE")"

: ${LIB_DIR:="$(dirname "$INSTALL_LIB")"}

: ${QUIET:=false}
: ${WIPE:=false}

: ${SSH_AUTHORIZED_KEYS:="$HOME/.ssh/id_rsa.pub"}

: ${BASE_MOUNT_OPTS:="subvol=/,compress=zstd,noatime"}
: ${ROOT_MOUNT_OPTS:="compress=zstd,noatime"}
: ${BOOT_MOUNT_OPTS:="noauto,noatime"}

source "$LIB_DIR"/install.sh

upgrade() {
    find-partitions
    upgrade-root
    upgrade-boot
}

upgrade-root() {
    mount-base-device
    local roots=( $BASE/roots/* )
    local last_root=${roots[-1]}
    local -i last_subvolume=${last_root##$BASE/roots/}
    ROOT_SUBVOLUME=/roots/$((last_subvolume++))
    ROOT=$BASE/$ROOT_SUBVOLUME
    snapshot-subvolume $last_root $ROOT
}

upgrade-boot() {
    mount-boot-device
    install-kernel
    install-boot-config
}
