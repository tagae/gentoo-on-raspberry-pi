test -v KERNEL_LIB && return || readonly KERNEL_LIB="$(realpath "$BASH_SOURCE")"

: ${LIB_DIR:="$(dirname "$KERNEL_LIB")"}

: ${KERNEL_SRC:=install.d/linux}
: ${FIRMWARE_SRC:=install.d/firmware}
: ${PROFILE:=virt}

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
    if test -d $KERNEL_SRC; then
        update-repo-if-older-than $KERNEL_SRC '1 day'
    else
        # use default repo branch
        git clone --branch rpi-5.7.y --depth 1 https://github.com/raspberrypi/linux $KERNEL_SRC
    fi
}

build-kernel() {
    config-kernel
    make-kernel "$@"
    BUILT_KERNEL=$KERNEL_SRC/arch/$CROSSDEV_ARCH/boot/
}

config-kernel() {
    milestone
    cp -uv profiles/"$PROFILE"/linux.config $KERNEL_SRC/.config
    if [ -v MACHINE ]; then
        set-kernel-config DEFAULT_HOSTNAME "$MACHINE"
    fi
    if [ -v PROFILE ]; then
        set-kernel-config LOCALVERSION "-$PROFILE"
    fi
}

set-kernel-config() {
    local -r key="$1" value="$2"
    sed -i 's/CONFIG_'$key'="[^"]*"/CONFIG_'$key'="'"$value"'"/g' $KERNEL_SRC/.config
}

make-kernel() {
    milestone "$@"
    cross-make \
        ${DEFAULTCONFIG:+${PLATFORM:-}${PLATFORM:+_}defconfig} \
        ${MENUCONFIG:+menuconfig} \
        "$@"
}

cross-make() {
    make -C $KERNEL_SRC ARCH=$CROSSDEV_ARCH CROSS_COMPILE=$CROSSDEV_TARGET- --jobs $(nproc) "$@"
}

install-kernel-image() {
    milestone
    cp -uv $BUILT_KERNEL/Image $BOOT/$KERNEL_IMAGE_NAME
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
    if [ -d $FIRMWARE_SRC ]; then
        update-repo-if-older-than $FIRMWARE_SRC '1 day'
    else
        git clone --branch stable --depth 1 https://github.com/raspberrypi/firmware $FIRMWARE_SRC
    fi
}

install-firmware() {
    milestone
    cp -uv $FIRMWARE_SRC/boot/{start*.elf,fixup*.dat,LICENCE.broadcom} $BOOT/
}
