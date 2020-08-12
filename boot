#!/bin/bash -eu

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(dirname "$(realpath "$0")")"

source "$SCRIPT_DIR"/lib/boot.sh
source "$SCRIPT_DIR"/lib/package.sh

usage() {
    die <<EOM
Usage: $SCRIPT_NAME [OPTION]... MEDIA

Boots MEDIA in a generic 64-bit ARM machine.
MEDIA can be generated with the 'package' command.

Options:

  -h   print this help message
  -d   run as daemon in the background

Environment variables:

  MENUCONFIG   if defined, configure kernel before building

Sample invocation:

  $0 gentoo.rpi4.img   # boot the gentoo.rpi4.img image

EOM
}

while getopts :hd OPTION; do
    case $OPTION in
        h) usage ;;
        d) DAEMON=true ;;
        \?) usage ;;
    esac
done
shift $((OPTIND-1))

(( $# == 1 )) || usage

readonly MEDIA="$1"

test -f "$MEDIA" || die "File not found: $MEDIA"

parse-media-name
[ -f profiles/"$PROFILE".sh ] || die "unsupported profile '$PROFILE'"
source profiles/"$PROFILE".sh

cd "$SCRIPT_DIR"

boot
