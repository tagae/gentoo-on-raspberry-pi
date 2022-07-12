test -v BOOT_VIRT_FACET && return || readonly BOOT_VIRT_FACET="$(realpath "$BASH_SOURCE")"

QEMU_OPTS+=(
    -device virtio-rng
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

if [ -v SSH_FWD ]; then
    QEMU_OPTS+=(
        -nic user,model=virtio,hostfwd=tcp::$SSH_FWD-:22
    )
fi

if [ -v TAP ]; then
    echo Setting up bridged TAP interface...
    ip tuntap add $TAP mode tap
    CLEANUPS+=("ip link delete $TAP")
    ip link set dev $TAP up
    systemd-resolve --set-mdns=yes --interface=$TAP
    QEMU_OPTS+=(
        -net nic,model=virtio
        -net tap,ifname=$TAP,script=no,downscript=no
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
