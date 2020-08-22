emaint sync --repo gentoo

case $(uname -m) in
    x86_64)
        : ${PORTAGE_PROFILE:=default/linux/amd64/17.1/systemd} ;;
    aarch64)
        : ${PORTAGE_PROFILE:=default/linux/arm64/17.0/systemd} ;;
esac

eselect profile set $PORTAGE_PROFILE
