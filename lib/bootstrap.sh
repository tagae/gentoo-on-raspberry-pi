test -v BOOTSTRAP_LIB && return || readonly BOOTSTRAP_LIB="$(realpath "$BASH_SOURCE")"

: ${LIB_DIR:="$(dirname "$BOOTSTRAP_LIB")"}

: ${QUIET:=false}
: ${WIPE:=false}

source "$LIB_DIR"/ui.sh
source "$LIB_DIR"/common.sh
source "$LIB_DIR"/btrfs.sh
source "$LIB_DIR"/gentoo.sh

bootstrap() {
    if $WIPE && [ -f "$ROOT"/etc/os-release ]; then
        delete-subvolume "$ROOT"
    fi
    [ -d "$ROOT" ] || create-subvolume "$ROOT"
    [ -f "$ROOT"/etc/os-release ] || install-stage3
}

install-stage3() {
    [ -v STAGE3_URL ] || find-latest-stage3
    local -r STAGE3_ARCHIVE="${STAGE3_URL##*/}"
    fetch-stage3
    extract-stage3
}

find-latest-stage3() {
    cd bootstrap.d
    local -A machine_platforms=( [x86_64]=amd64 )
    local -r machine=$(uname -m)
    [ -v machine_platforms[$machine] ] || die "Unsupported platform: $machine"
    local -r platform=${machine_platforms[$machine]}
    local -r stampfile=latest-stage3-"$platform"-systemd.txt
    local -r distfiles_url=http://distfiles.gentoo.org/releases/"$platform"/autobuilds

    if older-than "$stampfile" '15 days'; then
        curl ${QUIET:+--silent --show-error} --fail --remote-name "$distfiles_url/$stampfile"
    fi

    local stage3_archive_path stage3_size
    read stage3_archive_path stage3_size <<< $(grep -v '^#' "$stampfile")

    STAGE3_URL="$distfiles_url/$stage3_archive_path"
    cd - > /dev/null
}

fetch-stage3() {
    milestone ${STAGE3_ARCHIVE%%.*}
    cd bootstrap.d
    for suffix in '' .CONTENTS{,.gz} .DIGESTS; do
        local file="$STAGE3_ARCHIVE$suffix" remote="$STAGE3_URL$suffix"
        if ! test -f $file; then
            if curl --silent --head --fail --output /dev/null "$remote"; then
                curl ${QUIET:+--silent --show-error} --fail --remote-name "$remote"
            fi
        fi
    done
    check-download-integrity
    cd - > /dev/null
}

check-download-integrity() {
    local -r digests="$STAGE3_ARCHIVE.DIGESTS"
    local -r sha512digests="$digests.SHA512"
    if ! [ -f $sha512digests ]; then
        grep -A 1 --no-group-separator SHA512 < $digests > $sha512digests
        if ! sha512sum -c $sha512digests; then
            rm -vf $STAGE3_ARCHIVE{,.CONTENTS.gz,.DIGESTS,.DIGESTS.SHA512}
            die 'Deleted corrupted stage3 downloads'
        fi
    fi
}

extract-stage3() {
    milestone
    tar xpf bootstrap.d/$STAGE3_ARCHIVE --xattrs-include='*.*' --numeric-owner -C "$ROOT"
}
