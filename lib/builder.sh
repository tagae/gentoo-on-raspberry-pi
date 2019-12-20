test -v BUILDER_LIB && return || readonly BUILDER_LIB="$(realpath "$BASH_SOURCE")"

: ${LIB_DIR:="$(dirname "$BUILDER_LIB")"}

: ${SSH_KEY:=$HOME/.ssh/id_rsa.pub}

: ${MEDIA:=$SCRIPT_NAME.img}
: ${MEDIA_SIZE:=8g}

source "$LIB_DIR"/system.sh
source "$LIB_DIR"/package.sh

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
    bind-project-directory
    bind-public-ssh-key
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
