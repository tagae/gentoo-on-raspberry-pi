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

CONFIG=(arm_64bit=1)
CMDLINE=(init=/lib/systemd/systemd)
SUBVOLUMES=(
    /var
    /home
)

install() {
    source-from install.d/facets ${FACETS:-}
    find-partitions || WIPE=true
    if $WIPE; then
        partition-media
        find-partitions
        create-file-systems
    fi
    install-base
    install-root
    install-boot
    config-fstab
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

install-base() {
    mount-base-device
    for subvol in "${SUBVOLUMES[@]}"; do
        create-subvolume $BASE/$subvol
    done
}

mount-base-device() {
    BASE=$(make-temp-dir)
    mount-dir "$BASE_DEVICE" "$BASE" "$BASE_MOUNT_OPTS"
}

install-root() {
    define-root
    mount-data-subvolumes
    bootstrap-root
    crossdev-unneeded || enable-emulation
    provision-files
    config-systemd
    config-ssh-access
    set-root-password
}

define-root() {
    mkdir -vp $BASE/root
    ROOT_VERSION="$(date +%Y-%m-%d-%H-%M-%S)"
    ROOT_SUBVOLUME=/root/$ROOT_VERSION
    ROOT=$BASE/$ROOT_SUBVOLUME
    CMDLINE+=(
        root="PARTUUID=$(blkid -s PARTUUID -o value "$BASE_DEVICE")"
        rootfstype=btrfs
        rootflags=subvol=$ROOT_SUBVOLUME
        rootwait
    )
    local -r roots=( $BASE/root/* )
    if (( ${#roots[@]} == 0 )) || ${CLEAN:-false}; then
        create-subvolume $ROOT
    else
        snapshot-subvolume ${roots[-1]} $ROOT
    fi
}

mount-data-subvolumes() {
    for subvol in "${SUBVOLUMES[@]}"; do
        mkdir -pv $ROOT/$subvol
        touch $ROOT/$subvol/.keep
        mount-dir $BASE_DEVICE $ROOT/$subvol subvol=$subvol
    done
}

bootstrap-root() {
    milestone
    env ARCH=arm64 ./bootstrap -q "$ROOT"
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
    install-kernel-cmdline
    install-boot-config
}

mount-boot-device() {
    BOOT=$(make-temp-dir)
    mount-dir "$BOOT_DEVICE" "$BOOT" "$BOOT_MOUNT_OPTS"
}

install-kernel-cmdline() {
    milestone
    local -r cmdline_file=cmdline-$ROOT_VERSION.txt
    echo "# $cmdline_file"
    tee $KERNEL_HOME/$cmdline_file <<<"${CMDLINE[@]}"
    CONFIG+=(cmdline=$cmdline_file)
}

install-boot-config() {
    milestone
    CONFIG+=(os_prefix=$KERNEL_BRANCH/)
    local config_file=$BOOT/config.txt
    if test -f $BOOT/config.txt; then
        config_file=$BOOT/tryboot.txt
    fi
    echo "# $config_file"
    ( IFS=$'\n'; tee $config_file <<<"${CONFIG[*]}" )
}

config-fstab() {
    milestone
    local boot_dev_spec base_dev_spec
    boot_dev_spec="UUID=$(blkid -s UUID -o value "$BOOT_DEVICE")"
    base_dev_spec="UUID=$(blkid -s UUID -o value "$BASE_DEVICE")"
    local -r fstab=(
        "$boot_dev_spec /boot vfat  $BOOT_MOUNT_OPTS 0 2"
        "$base_dev_spec /     btrfs subvol=$ROOT_SUBVOLUME,$ROOT_MOUNT_OPTS 0 1"
        "$base_dev_spec /var  btrfs subvol=/var,noatime,nodev,nosuid 0 2"
        "$base_dev_spec /home btrfs subvol=/home,noatime,nodev,nosuid 0 2"
    )
    grep -E '^(#|$)' $ROOT/etc/fstab > $ROOT/etc/fstab.new
    ( IFS=$'\n'; tee --append $ROOT/etc/fstab.new <<<"${fstab[*]}" )
    mv $ROOT/etc/fstab.new $ROOT/etc/fstab
}
