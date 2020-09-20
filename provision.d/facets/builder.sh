test -v PROVISION_BUILDER && return || readonly PROVISION_BUILDER="$(realpath "$BASH_SOURCE")"

source "$LIB_DIR"/gentoo.sh
source "$LIB_DIR"/builder.sh

case $(uname -m) in
    x86_64)
        : ${PORTAGE_PROFILE:=default/linux/amd64/17.1/systemd} ;;
    aarch64)
        : ${PORTAGE_PROFILE:=default/linux/arm64/17.0/systemd} ;;
esac

sync-portage-tree
set-portage-profile
install-builder-packages
