test -v INSTALL_BASE_FACET && return || readonly INSTALL_BASE_FACET="$(realpath "$BASH_SOURCE")"

KERNEL_REPO=https://github.com/raspberrypi/linux
KERNEL_BRANCH=rpi-5.15.y
KERNEL_IMAGE_NAME=kernel.img

FIRMWARE_REPO=https://github.com/raspberrypi/firmware
FIRMWARE_BRANCH=stable

STAGE3_URL=http://distfiles.gentoo.org/experimental/arm64/stage3-arm64-systemd-20190925.tar.bz2
