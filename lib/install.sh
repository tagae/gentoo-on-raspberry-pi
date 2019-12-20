test -v INSTALL_LIB && return || readonly INSTALL_LIB="$(realpath "$BASH_SOURCE")"

: ${LIB_DIR:="$(dirname "$INSTALL_LIB")"}

: ${QUIET:=false}
: ${WIPE:=false}

: ${SSH_AUTHORIZED_KEYS:="$HOME/.ssh/id_rsa.pub"}

: ${BASE_MOUNT_OPTS:="subvol=/,compress=zstd,noatime"}
: ${ROOT_MOUNT_OPTS:="subvol=/root,compress=zstd,noatime"}
: ${BOOT_MOUNT_OPTS:="noauto,noatime"}

source "$LIB_DIR"/crossdev.sh
source "$LIB_DIR"/kernel.sh
source "$LIB_DIR"/ui.sh

install() {
    partition-media
    create-file-systems
    mount-partitions
    install-root
    install-boot
}

partition-media() {
    if $WIPE || ! find-partitions; then
        sfdisk --wipe=always --wipe-partition=always "$DEVICE" < install.d/partitions.sfdisk
        sync
        WIPE=true # force creation of new file systems
    fi
}

find-partitions() {
    local -r devices=("$DEVICE"*)
    if (( ${#devices[@]} == 3 )); then
        # $DEVICE itself is at position 0
        BOOT_DEVICE="${devices[1]}"
        BASE_DEVICE="${devices[2]}"
    else
        echo "Expected 2 partitions, but found ${devices[@]}"
        false
    fi
}

create-file-systems() {
    find-partitions
    if $WIPE; then
        mkfs.fat -c -f 1 -F 32 -n boot -v "$BOOT_DEVICE"
        mkfs.btrfs -L base "$BASE_DEVICE"
    fi
}

mount-partitions() {
    mount-dir "$BASE_DEVICE" "$BASE" "$BASE_MOUNT_OPTS"
    mount-dir "$BOOT_DEVICE" "$BOOT" "$BOOT_MOUNT_OPTS"
}

install-root() {
    bootstrap-root
    crossdev-unneeded || enable-emulation
    config-fstab
    config-etc
    config-journal
    config-networking
    config-ssh-access
    set-root-password
}

bootstrap-root() {
    milestone "$STAGE3_URL"
    ./bootstrap -qu "$STAGE3_URL" "$ROOT"
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

config-journal() {
    chattr -V +C /var/log/journal/
}

config-networking() {
    milestone
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
    install-kernel
    install-boot-config
}

install-boot-config() {
    milestone
    local -r cmdline=(
        console=ttyS0,115200
        root=PARTUUID="$(blkid -s PARTUUID -o value $BASE_DEVICE)"
        rootfstype=btrfs
        rootflags=subvol=/root
        rootwait
        init=/usr/lib/systemd/systemd
    )
    local -r config=(
        enable_uart=1
    )
    echo cmdline.txt:
    echo "${cmdline[@]}" | tee $BOOT/cmdline.txt
    echo
    echo config.txt:
    echo "${config[@]}" | tee $BOOT/config.txt
}
