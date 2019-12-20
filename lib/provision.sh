test -v PROVISION_LIB && return || readonly PROVISION_LIB="$(realpath "$BASH_SOURCE")"

: ${LIB_DIR:="$(dirname "$PROVISION_LIB")"}

: ${PORTAGE_PROFILE:=default/linux/amd64/17.1/systemd}

source "$LIB_DIR"/common.sh
source "$LIB_DIR"/gentoo.sh
source "$LIB_DIR"/kernel.sh
source "$LIB_DIR"/btrfs.sh
source "$LIB_DIR"/crossdev.sh
source "$LIB_DIR"/ui.sh

sync-portage-tree() {
    milestone
    local repo
    repo="$(gentoo-repo)"
    if older-than "$repo"/Manifest '1 day'; then
        emaint sync --repo gentoo
    fi
}

set-portage-profile() {
    milestone $PORTAGE_PROFILE
    eselect profile set $PORTAGE_PROFILE
}

install-builder-packages() {
    milestone
    emerge --noreplace \
           sys-fs/btrfs-progs \
           sys-fs/dosfstools \
           dev-vcs/git \
           sys-devel/bc
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
