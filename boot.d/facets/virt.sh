test -v BOOT_VIRT_FACET && return || readonly BOOT_VIRT_FACET="$(realpath "$BASH_SOURCE")"

QEMU_OPTS+=(
    -device virtio-rng

    -drive file=$MEDIA,format=raw,if=virtio

    -device virtio-serial
    -chardev stdio,signal=off,mux=on,id=char0
    -device virtconsole,chardev=char0,id=console0

    -mon chardev=char0,mode=readline
)

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
