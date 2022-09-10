test -v KERNEL_LIB && return || readonly KERNEL_LIB="$(realpath "$BASH_SOURCE")"

: ${LIB_DIR:="$(dirname "$KERNEL_LIB")"}

: ${KERNEL_SRC:=install.d/linux}
: ${FIRMWARE_SRC:=install.d/firmware}

source "$LIB_DIR"/runtime.sh
source "$LIB_DIR"/git.sh
source "$LIB_DIR"/ui.sh

# https://www.raspberrypi.org/documentation/linux/kernel/building.md
install-kernel() {
    fetch-kernel
    build-kernel Image modules dtbs
    install-kernel-image
    install-kernel-modules
    install-device-tree
    install-overlays
    fetch-firmware
    install-firmware
}

fetch-kernel() {
    milestone
    fetch-branch $KERNEL_REPO $KERNEL_BRANCH '1 day' $KERNEL_SRC
}

build-kernel() {
    config-kernel
    make-kernel "$@"
    BUILT_KERNEL=$KERNEL_SRC/arch/$CROSSDEV_ARCH/boot/
}

config-kernel() {
    milestone
    apply-kernel-config install.d/facets $FACETS
    cross-make KCONFIG_ALLCONFIG=combined.config \
               ${CLEAN:+clean} \
               allnoconfig \
               ${MENUCONFIG:+menuconfig}
    if [ -v MACHINE ]; then
        set-kernel-config DEFAULT_HOSTNAME "$MACHINE"
    fi
    if [ -v PROFILE ]; then
        set-kernel-config LOCALVERSION "-$PROFILE"
    fi
}

apply-kernel-config() {
    local CONFIG_DIR="$1"
    shift
    ( cd $CONFIG_DIR; realpath -eq ${@/%/.linux.config} | xargs cat ) | \
        grep -Ev '^[[:space:]]*(#|$)' | sort | uniq > $KERNEL_SRC/combined.config
}

set-kernel-config() {
    local -r key="$1" value="$2"
    sed -i 's/CONFIG_'$key'="[^"]*"/CONFIG_'$key'="'"$value"'"/g' $KERNEL_SRC/.config
}

make-kernel() {
    milestone "$@"
    cross-make "$@"
}

cross-make() {
    make --jobs $(nproc) -C $KERNEL_SRC ARCH=$CROSSDEV_ARCH CROSS_COMPILE=$CROSSDEV_TARGET- "$@"
}

kernel-image-name() {
    local -r branch_and_config_hash=$(sha512sum <<<"$KERNEL_BRANCH $(<$KERNEL_SRC/combined.config)")
    echo kernel-${branch_and_config_hash:0:12}.img
}

install-kernel-image() {
    milestone
    local -r kernel_image_name=$(kernel-image-name)
    cp -uv $BUILT_KERNEL/Image $BOOT/$kernel_image_name
    CONFIG+=(kernel=$kernel_image_name)
}

install-kernel-modules() {
    milestone
    cross-make INSTALL_MOD_PATH=$ROOT modules_install
}

install-device-tree() {
    [ -v DEVICE_TREE ] || return 0
    milestone
    cp -uv $BUILT_KERNEL/dts/$DEVICE_TREE $BOOT/
}

install-overlays() {
    milestone
    mkdir -pv $BOOT/overlays
    cp -uv $BUILT_KERNEL/dts/overlays/README $BOOT/overlays/
    if [ -v OVERLAYS ]; then
        cp -uv $BUILT_KERNEL/dts/overlays/{$OVERLAYS}.dtbo $BOOT/overlays/
    fi
}

fetch-firmware() {
    milestone
    fetch-branch $FIRMWARE_REPO $FIRMWARE_BRANCH '1 day' $FIRMWARE_SRC
}

install-firmware() {
    milestone
    cp -uv $FIRMWARE_SRC/boot/{start*.elf,fixup*.dat,LICENCE.broadcom} $BOOT/
}
