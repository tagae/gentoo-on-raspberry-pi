test -v BOOT_LIB && return || readonly BOOT_LIB="$(realpath "$BASH_SOURCE")"

: ${LIB_DIR:="$(dirname "$BOOT_LIB")"}

source "$LIB_DIR"/runtime.sh
source "$LIB_DIR"/ui.sh
source "$LIB_DIR"/package.sh
source "$LIB_DIR"/install.sh

boot() {
    source-from boot.d/facets ${FACETS:-}
    mount-boot-partition
    boot-system
}

mount-boot-partition() {
    milestone
    attach-device
    find-partitions
    mount-boot-device
}

boot-system() {
    milestone
    (
        set -x

        # Use ctrl-a c to switch between the guest serial console and the QEMU monitor
        # Use ctrl-a x to terminate the VM
        qemu-system-aarch64 \
            -nodefaults \
            -no-user-config \
            -machine virt \
            -cpu cortex-a72 \
            -smp 1 \
            -m 512 \
            -nographic \
            ${DAEMON:+-daemonize} \
            -kernel "$BOOT"/kernel*.img \
            -append "$(< $BOOT/cmdline*.txt)" \
            "${QEMU_OPTS[@]}"
    )
}
