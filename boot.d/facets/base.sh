test -v BOOT_BASE_FACET && return || readonly BOOT_BASE_FACET="$(realpath "$BASH_SOURCE")"

QEMU_OPTS=()
