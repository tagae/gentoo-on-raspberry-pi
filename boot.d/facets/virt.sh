test -v BOOT_VIRT_FACET && return || readonly BOOT_VIRT_FACET="$(realpath "$BASH_SOURCE")"

QEMU_OPTS+=(
    -device virtio-rng
    -nic user,model=virtio,hostfwd=tcp::2222-:22
    -drive file=$MEDIA,format=raw,if=virtio
)

if ! ${DAEMON:-false}; then
    QEMU_OPTS+=(
        -device virtio-serial
        -chardev stdio,signal=off,mux=on,id=char0
        -device virtconsole,chardev=char0,id=console0
        -mon chardev=char0,mode=readline
    )
fi

if [ -v MACVTAP ]; then
    echo Setting up bridged macvtap interface linked to $MACVTAP...
    ip link add link $MACVTAP name macvtap0 type macvtap mode bridge
    ip link set dev $MACVTAP allmulticast on
    CLEANUPS+=('ip link delete macvtap0')
    ip link set macvtap0 up
    CLEANUPS+=('ip link set macvtap0 down')
    ip link show macvtap0
    exec {MACVTAP_FD}<>/dev/tap$(< /sys/class/net/macvtap0/ifindex)
    CLEANUPS+=("exec {MACVTAP_FD}>&-")
    QEMU_OPTS+=(
        -net nic,model=virtio,macaddr=$(< /sys/class/net/macvtap0/address)
        -net tap,fd=$MACVTAP_FD
    )
fi
