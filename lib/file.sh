test -v FILE_LIB && return || readonly FILE_LIB="$(realpath $BASH_SOURCE)"

older-than() {
    local -r file="$1" max_age="$2"
    local -i last_update oldest_allowed
    if [ -e "$file" ]; then
        last_update=$(date -r "$file" +%s)
        oldest_allowed=$(date -d "now - $max_age" +%s)
        (( last_update < oldest_allowed ))
    else
        true
    fi
}

make-temp-dir() {
    local dir
    dir=$(mktemp -dp '' ${SCRIPT_NAME}-XXX)
    CLEANUPS+=("rmdir -v $dir")
    echo "$dir"
}
