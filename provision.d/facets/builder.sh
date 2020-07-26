test -v PROVISION_BUILDER && return || readonly PROVISION_BUILDER="$(realpath "$BASH_SOURCE")"

source "$LIB_DIR"/gentoo.sh
source "$LIB_DIR"/builder.sh

sync-portage-tree
set-portage-profile
install-builder-packages
