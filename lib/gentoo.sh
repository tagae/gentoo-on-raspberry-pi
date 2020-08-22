test -v GENTOO_LIB && return || readonly GENTOO_LIB="$(realpath "$BASH_SOURCE")"

is-gentoo() {
    local -r root="${1:-}"
    if test -f "$root"/etc/os-release; then
        ( source "$root"/etc/os-release && test "$NAME" = Gentoo; )
    else
        false
    fi
}

gentoo-repo() {
    portageq get_repo_path "${1:-/}" gentoo
}

sync-portage-tree() {
    milestone
    local repo
    repo="$(gentoo-repo)"
    if older-than "$repo"/Manifest '1 day'; then
        emaint sync --repo gentoo
    fi
}

set-portage-profile() {
    milestone $PORTAGE_PROFILE
    eselect profile set $PORTAGE_PROFILE
}
