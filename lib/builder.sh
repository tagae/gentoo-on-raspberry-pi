test -v BUILDER_LIB && return || readonly BUILDER_LIB="$(realpath "$BASH_SOURCE")"

: ${LIB_DIR:="$(dirname "$BUILDER_LIB")"}

: ${SSH_KEY:=$HOME/.ssh/id_rsa.pub}

: ${MEDIA:=$SCRIPT_NAME.img}
: ${MEDIA_SIZE:=8g}

source "$LIB_DIR"/package.sh
source "$LIB_DIR"/chroot.sh
source "$LIB_DIR"/gentoo.sh
source "$LIB_DIR"/mount.sh
source "$LIB_DIR"/file.sh
source "$LIB_DIR"/ui.sh

create-builder-media() {
    [ -f $MEDIA ] && return 0
    create-media
    mkfs.btrfs -L $SCRIPT_NAME $MEDIA
}

mount-builder-media() {
    attach-device
    mount-dir $DEVICE $BASE
}

bootstrap-builder() {
    echo Setting up builder environment at $ROOT...
    ./bootstrap -q $ROOT
}

setup-builder-chroot() {
    bind-system-dirs
    bind-file $(realpath -e /etc/resolv.conf) $ROOT/etc/resolv.conf
    bind-dir /run $ROOT/run
    bind-project-directory
    bind-public-ssh-key
    bind-portage-tree
}

bind-project-directory() {
    bind-dir "$SCRIPT_DIR" "$ROOT/$BUILDER_DIR"
}

bind-public-ssh-key() {
    [ -f "$SSH_KEY" ] || return 0
    local -r BUILDER_SSH_DIR="$ROOT/$BUILDER_HOME/.ssh"
    mkdir -vp --mode go-rwx "$BUILDER_SSH_DIR"
    bind-file "$SSH_KEY" "$BUILDER_SSH_DIR"/"$(basename "$SSH_KEY")"
}

bind-portage-tree() {
    command -v portageq > /dev/null || return 0
    bind-dir "$(gentoo-repo)" "$ROOT/$(gentoo-repo "$ROOT")"
}

install-builder-packages() {
    milestone
    mkdir -vp /etc/portage/sets
    cat > /etc/portage/sets/builder <<-EOP
           sys-fs/btrfs-progs
           sys-fs/dosfstools
           dev-vcs/git
           sys-devel/bc
           dev-tcltk/expect
EOP
    emerge -u @builder
}
