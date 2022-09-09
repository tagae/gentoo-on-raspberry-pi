test -v INSTALL_LIB && return || readonly INSTALL_LIB="$(realpath "$BASH_SOURCE")"

: ${LIB_DIR:="$(dirname "$INSTALL_LIB")"}

source "$LIB_DIR"/runtime.sh
source "$LIB_DIR"/mount.sh
source "$LIB_DIR"/file.sh
source "$LIB_DIR"/chroot.sh
source "$LIB_DIR"/gentoo.sh
source "$LIB_DIR"/crossdev.sh
source "$LIB_DIR"/kernel.sh
source "$LIB_DIR"/btrfs.sh
source "$LIB_DIR"/git.sh
source "$LIB_DIR"/ui.sh

: ${QUIET:=false}
: ${WIPE:=false}

: ${SSH_AUTHORIZED_KEYS:="$HOME/.ssh/id_rsa.pub"}

: ${BASE_MOUNT_OPTS:="subvol=/,compress=zstd,noatime"}
: ${ROOT_MOUNT_OPTS:="compress=zstd,noatime"}
: ${BOOT_MOUNT_OPTS:="noauto,noatime"}

: ${INSTALL_VERSION=$(git-short-commit-hash)}

CMDLINE=()
CONFIG=()

install() {
    source-from install.d/facets ${FACETS:-}
    find-partitions || WIPE=true
    if $WIPE; then
        partition-media
        find-partitions
        create-file-systems
    fi
    install-root
    install-boot
}

partition-media() {
    milestone
    sfdisk --wipe=always --wipe-partition=always "$DEVICE" < install.d/partitions.sfdisk
    sync
}

find-partitions() {
    local -r devices=("$DEVICE"*)
    (( ${#devices[@]} == 3 )) || return 1
    # $DEVICE itself is at position 0
    BOOT_DEVICE="${devices[1]}"
    BASE_DEVICE="${devices[2]}"
}

create-file-systems() {
    milestone
    ( set -x; mkfs.fat -c -f 1 -F 32 -n boot -v "$BOOT_DEVICE"; )
    echo
    ( set -x; mkfs.btrfs -L base "$BASE_DEVICE"; )
}

install-root() {
    bootstrap-root
    crossdev-unneeded || enable-emulation
    provision-files
    config-fstab
    config-systemd
    config-ssh-access
    set-root-password
}

bootstrap-root() {
    milestone
    mount-base-device
    ROOT_SUBVOLUME=/root-$INSTALL_VERSION
    ROOT=$BASE/$ROOT_SUBVOLUME
    env ARCH=arm64 ./bootstrap -q "$ROOT"
    CMDLINE+=(
        root=PARTUUID="$(blkid -s PARTUUID -o value $BASE_DEVICE)"
        rootfstype=btrfs
        rootflags=subvol=$ROOT_SUBVOLUME
        rootwait
    )
}

mount-base-device() {
    BASE=$(make-temp-dir)
    mount-dir "$BASE_DEVICE" "$BASE" "$BASE_MOUNT_OPTS"
}

enable-emulation() {
    milestone
    bind-file /usr/bin/qemu-aarch64 "$ROOT"/usr/bin/qemu-aarch64
}

provision-files() {
    milestone
    local facet facet_dir
    for facet in $FACETS; do
        facet_files=install.d/files/$facet/
        if [[ -d "$facet_files" ]]; then
            cp -uvr $facet_files/* "$ROOT"/
        fi
    done
}

config-fstab() {
    milestone
    local boot_uuid base_uuid
    boot_uuid="$(blkid -s UUID -o value "$BOOT_DEVICE")"
    base_uuid="$(blkid -s UUID -o value "$BASE_DEVICE")"
    {
        fstab-has "^UUID=$boot_uuid" || echo "UUID=$boot_uuid /boot vfat $BOOT_MOUNT_OPTS 1 2"
        fstab-has "subvol=$ROOT_SUBVOLUME" || echo "UUID=$base_uuid / btrfs subvol=$ROOT_SUBVOLUME,$ROOT_MOUNT_OPTS 0 0"
    } | tee --append "$ROOT"/etc/fstab
}

fstab-has() {
    local -r expression="$1"
    egrep -q "$expression" "$ROOT"/etc/fstab
}

config-systemd() {
    milestone
    chattr -V +C "$ROOT"/var/log/journal/
    chroot "$ROOT" systemd-machine-id-setup
    chroot "$ROOT" systemctl enable systemd-networkd systemd-resolved sshd
    CMDLINE+=(
        init=/lib/systemd/systemd
        systemd.gpt_auto=no
    )
}

config-ssh-access() {
    milestone
    generate-ssh-keys
    local -r ssh_dir="$ROOT"/root/.ssh
    [ -d "$ssh_dir" ] || mkdir -v --mode go-rwx "$ssh_dir"
    cp -uv "$SSH_AUTHORIZED_KEYS" "$ssh_dir"/authorized_keys
    chmod -cv go-rwx "$ssh_dir"/authorized_keys
}

generate-ssh-keys() {
    [ -f "$SSH_AUTHORIZED_KEYS" ] && return 0
    local -r ssh_key=install.d/ssh/"$MACHINE"
    mkdir -pv "$(dirname $ssh_key)"
    [ -f "$ssh_key" ] || ssh-keygen -t rsa -b 4096 -q -N '' -f "$ssh_key"
    SSH_AUTHORIZED_KEYS="$ssh_key".pub
}

set-root-password() {
    [ -v PASSWORD ] || return 0
    milestone
    chroot "$ROOT" chpasswd <<<"root:$PASSWORD"
}

install-boot() {
    mount-boot-device
    install-kernel
    install-kernel-cmdline
    install-boot-config
}

mount-boot-device() {
    BOOT=$(make-temp-dir)
    mount-dir "$BOOT_DEVICE" "$BOOT" "$BOOT_MOUNT_OPTS"
}

install-kernel-cmdline() {
    milestone
    local -r cmdline_file=cmdline-$INSTALL_VERSION.txt
    echo '# $cmdline_file'
    tee $BOOT/$cmdline_file <<<"${CMDLINE[*]}"
    CONFIG+=(cmdline=$cmdline_file)
}

install-boot-config() {
    milestone
    echo '# config.txt'
    tee $BOOT/config.txt <<<"${CONFIG[*]}"
}
