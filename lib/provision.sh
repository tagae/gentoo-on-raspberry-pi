test -v PROVISION_LIB && return || readonly PROVISION_LIB="$(realpath "$BASH_SOURCE")"

: ${LIB_DIR:="$(dirname "$PROVISION_LIB")"}

source "$LIB_DIR"/runtime.sh
source "$LIB_DIR"/gentoo.sh
source "$LIB_DIR"/kernel.sh
source "$LIB_DIR"/btrfs.sh
