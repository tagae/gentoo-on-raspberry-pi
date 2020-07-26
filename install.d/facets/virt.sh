test -v INSTALL_VIRT_FACET && return || readonly INSTALL_VIRT_FACET="$(realpath "$BASH_SOURCE")"

CMDLINE+=(
    console=hvc0
)
