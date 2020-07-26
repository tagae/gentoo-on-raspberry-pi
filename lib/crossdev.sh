test -v CROSSDEV_LIB && return || readonly CROSSDEV_LIB="$(realpath "$BASH_SOURCE")"

source "$LIB_DIR"/ui.sh

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

crossdev-needed() {
    [ "$(uname -m)" != $CROSSDEV_MACHINE ]
}

crossdev-unneeded() {
    ! crossdev-needed
}

setup-crossdev() {
    install-crossdev-config
    install-crossdev-packages
    define-crossdev-repo
    install-crossdev
    set-crossdev-profile
    setup-qemu
}

install-crossdev-config() {
    milestone
    cp -urv provision.d/crossdev/* /
}

install-crossdev-packages() {
    milestone
    emerge --noreplace app-emulation/qemu sys-devel/crossdev
}

define-crossdev-repo() {
    milestone
    local -r crossdev_conf=/etc/portage/repos.conf/crossdev.conf
    mkdir -pv $(dirname $crossdev_conf)
    echo
    { cat <<END
[crossdev]

location = $CROSSDEV_LOCATION
priority = 10
masters = gentoo
auto-sync = no
END
    } | tee $crossdev_conf
    echo
    mkdir -pv $CROSSDEV_LOCATION
}

install-crossdev() {
    milestone
    crossdev --stable --target $CROSSDEV_TARGET
}

set-crossdev-profile() {
    milestone $CROSSDEV_PROFILE
    ARCH=$CROSSDEV_ARCH PORTAGE_CONFIGROOT=/usr/$CROSSDEV_TARGET eselect profile set $CROSSDEV_PROFILE
}

setup-qemu() {
    milestone
    gpasswd -a $USER kvm
    local -r qemu_conf=/etc/binfmt.d/qemu-aarch64.conf
    [ -f $qemu_conf ] && grep -q :qemu-aarch64: $qemu_conf && return 0
    grep :qemu-aarch64: /usr/share/qemu/binfmt.d/qemu.conf >> $qemu_conf
    systemctl restart systemd-binfmt
}
