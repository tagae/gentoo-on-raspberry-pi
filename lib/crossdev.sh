test -v CROSSDEV_LIB && return || readonly CROSSDEV_LIB="$(realpath "$BASH_SOURCE")"

: ${CROSSDEV_ARCH:=arm64}

# See https://wiki.gentoo.org/wiki/Embedded_Handbook/Tuples
# See `crossdev -t help`
: ${CROSSDEV_MACHINE:=aarch64}
: ${CROSSDEV_VENDOR:=unknown}
: ${CROSSDEV_KERNEL:=linux}
: ${CROSSDEV_OS:=gnu}
: ${CROSSDEV_TARGET:=$CROSSDEV_MACHINE-$CROSSDEV_VENDOR-$CROSSDEV_KERNEL-$CROSSDEV_OS}

: ${CROSSDEV_PROFILE:=default/linux/arm64/17.0/systemd}
: ${CROSSDEV_LOCATION:=/usr/local/crossdev}

crossdev-unneeded() {
    [ "$(uname -m)" == $CROSSDEV_MACHINE ]
}
