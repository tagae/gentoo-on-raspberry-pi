test -v UI_LIB && return || readonly UI_LIB="$(realpath $BASH_SOURCE)"

milestone() {
    echo
    echo -- ${FUNCNAME[1]}${@:+:} "$@"
    echo
}
