#!/bin/bash -eu

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(dirname "$(realpath "$0")")"

source "$SCRIPT_DIR"/lib/boot.sh

usage() {
    die <<EOM
Usage: $SCRIPT_NAME [OPTION]... MEDIA

Boots MEDIA in a generic 64-bit ARM machine.
MEDIA can be generated with the 'package' command.

Options:

  -h   print this help message

Environment variables:

  MENUCONFIG   if defined, configure kernel before building

EOM
}

while getopts :h OPTION; do
    case $OPTION in
        h) usage ;;
        \?) usage ;;
    esac
done
shift $((OPTIND-1))

(( $# == 1 )) || usage

readonly MEDIA="$1"

parse-media-name

source profiles/"$PROFILE"/config.sh

cd "$SCRIPT_DIR"

test -f "$MEDIA" || die "File not found: $MEDIA"

boot
