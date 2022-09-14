test -v UPDATE_LIB && return || readonly UPDATE_LIB="$(realpath "$BASH_SOURCE")"

: ${LIB_DIR:="$(dirname "$UPDATE_LIB")"}

source "$LIB_DIR"/install.sh

update() {
    source-from install.d/facets ${FACETS:-}
    find-partitions
    update-root
    install-boot
    CONFIG_FILE=tryboot.txt install-boot
}

update-root() {
    mount-base-device
    CLEAN=false find-root-version
    local -r current_root=$ROOT
    ROOT=${current_root%%/$ROOT_VERSION}/$((ROOT_VERSION+1))
    snapshot-subvolume $current_root $ROOT
}
