#!/bin/bash -eu

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(dirname "$(realpath "$0")")"
readonly PROJECT_NAME="$(basename "$SCRIPT_DIR")"

source "$SCRIPT_DIR"/lib/builder.sh

usage() {
    die <<EOM
Usage: $SCRIPT_NAME COMMAND [ARGS]...

Executes the given COMMAND in a builder chroot(1).

Options:

  -h          print this help message

Sample invocation:

  sudo $0 ./provision                          # provision builder itself
  sudo $0 ./package gentoo.rpi4.img            # build image
  sudo $0 ./install gentoo rpi4 /dev/mmcblk0   # install directly on block device

EOM
}

while getopts :m:h OPTION; do
    case $OPTION in
        h) usage ;;
        \?) usage ;;
    esac
done
shift $((OPTIND-1))

(( $# > 0 )) || usage

readonly BASE=$(make-temp-dir)
readonly ROOT=$BASE/root

readonly BUILDER_HOME=/root
readonly BUILDER_DIR=$BUILDER_HOME/$PROJECT_NAME

export FACETS='base'

cd "$SCRIPT_DIR"

create-builder-media
mount-builder-media
bootstrap-builder
setup-builder-chroot

echo
echo "------------------------------"
echo "Running in builder environment"
echo "------------------------------"
echo

chroot $ROOT env --chdir="$BUILDER_DIR" HOME="$BUILDER_HOME" "$@"
