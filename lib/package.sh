test -v PACKAGE_LIB && return || readonly PACKAGE_LIB="$(realpath "$BASH_SOURCE")"

: ${LIB_DIR:="$(dirname "$PACKAGE_LIB")"}

: ${QUIET:=false}
: ${WIPE:=false}

source "$LIB_DIR"/mount.sh
source "$LIB_DIR"/install.sh

package() {
    create-media
    attach-device
    env WIPE=$WIPE ./install -q "$MACHINE" "$PROFILE" "$DEVICE"
}

attach-device() {
    local -r media="${1:-$MEDIA}"
    DEVICE=$(losetup --noheadings --output NAME --associated "$media")
    if test -z "$DEVICE"; then
        DEVICE=$(losetup --find)
        echo Attaching media...
        losetup -v --partscan $DEVICE "$media"
        CLEANUPS+=("detach-device $MEDIA")
    fi
}

detach-device() {
    local -r media="${1:-$MEDIA}"
    local -r device=$(losetup --noheadings --output NAME --associated "$media")
    if test -n "$device"; then
        echo Detaching $media from $device...
        losetup -v --detach "$device"
    fi
}

create-media() {
    test -f "$MEDIA" && return 0
    milestone $MEDIA
    if ! fallocate -v --length "${MEDIA_SIZE:-4g}" "$MEDIA"; then
        rm -f "$MEDIA"
        false
    fi
}

mount-media() {
    milestone $MEDIA
    attach-device
    find-partitions
    local -r BASE=$(make-temp-dir)
    local -r ROOT=$BASE/root
    local -r BOOT=$ROOT/boot
    mount-dir $BASE_DEVICE $ROOT subvol=root
    mount-dir $BOOT_DEVICE $BOOT
}

parse-media-name() {
    [[ "$MEDIA" =~ (.+)\.([^.]+)\.img ]] || \
        die 'expected filename of the form MACHINE.PROFILE.img'
    MACHINE="${BASH_REMATCH[1]}"
    PROFILE="${BASH_REMATCH[2]}"
}
