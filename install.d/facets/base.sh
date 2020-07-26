test -v INSTALL_BASE_FACET && return || readonly INSTALL_BASE_FACET="$(realpath "$BASH_SOURCE")"

KERNEL_REPO=https://github.com/raspberrypi/linux
KERNEL_BRANCH=rpi-5.7.y
KERNEL_IMAGE_NAME=kernel.img

STAGE3_URL=http://distfiles.gentoo.org/experimental/arm64/stage3-arm64-systemd-20190925.tar.bz2

CMDLINE=(
)
