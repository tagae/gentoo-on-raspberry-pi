test -v PROVISION_CROSSDEV && return || readonly PROVISION_CROSSDEV="$(realpath "$BASH_SOURCE")"

source "$LIB_DIR"/crossdev.sh

crossdev-needed || return 0

setup-crossdev
