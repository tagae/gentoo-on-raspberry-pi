test -v INSTALL_RPI4_FACET && return || readonly INSTALL_RPI4_FACET="$(realpath "$BASH_SOURCE")"

PLATFORM=bcm2711
KERNEL_IMAGE_NAME=kernel8.img
DEVICE_TREE=broadcom/bcm2711-rpi-4-b.dtb
CFLAGS="-march=armv8-a -mcpu=cortex-a72+crc -O2 -pipe"
CXXFLAGS="$CFLAGS"
CMDLINE+=(
    console=ttyS0,115200
)
ARCH=arm64
PORTAGE_PROFILE=default/linux/arm64/17.0/systemd
