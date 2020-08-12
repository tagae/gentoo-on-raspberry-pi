test -v INSTALL_LIB && return || readonly INSTALL_LIB="$(realpath "$BASH_SOURCE")"

: ${LIB_DIR:="$(dirname "$INSTALL_LIB")"}

: ${QUIET:=false}
: ${WIPE:=false}

: ${SSH_AUTHORIZED_KEYS:="$HOME/.ssh/id_rsa.pub"}

: ${BASE_MOUNT_OPTS:="subvol=/,compress=zstd,noatime"}
: ${ROOT_MOUNT_OPTS:="subvol=/root,compress=zstd,noatime"}
: ${BOOT_MOUNT_OPTS:="noauto,noatime"}

source "$LIB_DIR"/runtime.sh
source "$LIB_DIR"/mount.sh
source "$LIB_DIR"/file.sh
source "$LIB_DIR"/chroot.sh
source "$LIB_DIR"/gentoo.sh
source "$LIB_DIR"/crossdev.sh
source "$LIB_DIR"/kernel.sh
source "$LIB_DIR"/ui.sh

install() {
    source-from install.d/facets ${FACETS:-}
    partition-media
    create-file-systems
    install-root
    install-boot
}

partition-media() {
    if $WIPE || ! find-partitions; then
        milestone
        sfdisk --wipe=always --wipe-partition=always "$DEVICE" < install.d/partitions.sfdisk
        sync
        WIPE=true # force creation of new file systems
    fi
}

find-partitions() {
    local -r devices=("$DEVICE"*)
    (( ${#devices[@]} == 3 )) || return 1
    # $DEVICE itself is at position 0
    BOOT_DEVICE="${devices[1]}"
    BASE_DEVICE="${devices[2]}"
}

create-file-systems() {
    find-partitions
    if $WIPE; then
        milestone
        ( set -x; mkfs.fat -c -f 1 -F 32 -n boot -v "$BOOT_DEVICE"; )
        echo
        ( set -x; mkfs.btrfs -L base "$BASE_DEVICE"; )
    fi
}

install-root() {
    mount-base-device
    ROOT="$BASE/root"
    bootstrap-root
    crossdev-unneeded || enable-emulation
    config-fstab
    config-etc
    config-systemd
    config-ssh-access
    set-root-password
}

mount-base-device() {
    BASE=$(make-temp-dir)
    mount-dir "$BASE_DEVICE" "$BASE" "$BASE_MOUNT_OPTS"
}

bootstrap-root() {
    milestone
    env ARCH=arm64 ./bootstrap -q "$ROOT"
}

enable-emulation() {
    milestone
    bind-file /usr/bin/qemu-aarch64 "$ROOT"/usr/bin/qemu-aarch64
}

config-fstab() {
    milestone
    local boot_uuid base_uuid
    boot_uuid="$(blkid -s UUID -o value "$BOOT_DEVICE")"
    base_uuid="$(blkid -s UUID -o value "$BASE_DEVICE")"
    {
        fstab-has "^UUID=$boot_uuid" || echo "UUID=$boot_uuid /boot vfat $BOOT_MOUNT_OPTS 1 2"
        fstab-has "^UUID=$base_uuid" || echo "UUID=$base_uuid / btrfs $ROOT_MOUNT_OPTS 0 0"
    } | tee --append "$ROOT"/etc/fstab
}

fstab-has() {
    local -r expression="$1"
    egrep -q "$expression" "$ROOT"/etc/fstab
}

config-etc() {
    milestone
    cp -uvr install.d/etc/ "$ROOT"/
}

config-systemd() {
    milestone
    chattr -V +C "$ROOT"/var/log/journal/
    chroot "$ROOT" systemd-machine-id-setup
    chroot "$ROOT" systemctl enable systemd-networkd systemd-resolved sshd
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
    install-boot-config
}

mount-boot-device() {
    BOOT=$(make-temp-dir)
    mount-dir "$BOOT_DEVICE" "$BOOT" "$BOOT_MOUNT_OPTS"
}

install-boot-config() {
    milestone
    CMDLINE+=(
        root=PARTUUID="$(blkid -s PARTUUID -o value $BASE_DEVICE)"
        rootfstype=btrfs
        rootflags=subvol=/root
        rootwait
        init=/lib/systemd/systemd
        systemd.gpt_auto=no
    )
    local -r CONFIG=(
        enable_uart=1
    )
    echo '# cmdline.txt'
    tee $BOOT/cmdline.txt <<<"${CMDLINE[*]}"
    echo
    echo '# config.txt'
    tee $BOOT/config.txt <<<"${CONFIG[*]}"
    echo
}
