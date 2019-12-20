test -v BOOT_LIB && return || readonly BOOT_LIB="$(realpath "$BASH_SOURCE")"

: ${LIB_DIR:="$(dirname "$BOOT_LIB")"}

source "$LIB_DIR"/ui.sh
source "$LIB_DIR"/package.sh
source "$LIB_DIR"/install.sh
source "$LIB_DIR"/crossdev.sh

boot() {
    setup-boot-options
    setup-virtual-machine
    boot-system
}

setup-boot-options() {
    attach-device
    find-partitions
    BOOT=$(make-temp-dir)
    mount-dir $BOOT_DEVICE $BOOT
    KERNEL_IMAGE=$BOOT/$KERNEL_IMAGE_NAME
    CMDLINE=$(< $BOOT/cmdline.txt)
}

setup-virtual-machine() {
    QEMU_OPTS=(
        -rtc base=utc,clock=host
        -device virtio-rng
    )
    setup-virtual-console
    setup-virtual-drives
    setup-virtual-networking
}

setup-virtual-console() {
    QEMU_OPTS+=(
        -device virtio-serial
        -chardev stdio,signal=off,mux=on,id=char0
        -device virtconsole,chardev=char0,id=console0
        -mon chardev=char0,mode=readline
    )
    CMDLINE="$CMDLINE console=hvc0"
}

setup-virtual-drives() {
    QEMU_OPTS+=(
        -drive file=$MEDIA,format=raw,if=virtio
    )
}

setup-virtual-networking() {
    milestone
    if [ -v MACVTAP ]; then
        echo Setting up macvtap interface linked to $MACVTAP...
        ip link add link $MACVTAP name macvtap0 type macvtap mode bridge
        CLEANUPS+=('ip link delete macvtap0')
        ip link set macvtap0 up
        CLEANUPS+=('ip link set macvtap0 down')
        ip link show macvtap0
        exec {TAP_FD}<>/dev/tap$(< /sys/class/net/macvtap0/ifindex)
        CLEANUPS+=("exec {TAP_FD}>&-")
        QEMU_OPTS+=(
            -net nic,model=virtio,macaddr=$(< /sys/class/net/macvtap0/address)
            -net tap,fd=$TAP_FD
        )
    fi
    QEMU_OPTS+=(
        -nic user,model=virtio,hostfwd=tcp::2222-:22
    )
}

boot-system() {
    milestone $MACHINE
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
            -kernel "$KERNEL_IMAGE" \
            -append "$CMDLINE" \
            "${QEMU_OPTS[@]}"
    )
}
