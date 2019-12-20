readonly PLATFORM=bcm2711
readonly DEVICE_TREE=broadcom/bcm2711-rpi-4-b.dtb
readonly KERNEL_IMAGE_NAME=kernel8.img

readonly CFLAGS="-march=armv8-a -mcpu=cortex-a72+crc -O2 -pipe"
readonly CXXFLAGS="$CFLAGS"

: ${STAGE3_URL:=http://distfiles.gentoo.org/experimental/arm64/stage3-arm64-systemd-20190925.tar.bz2}
