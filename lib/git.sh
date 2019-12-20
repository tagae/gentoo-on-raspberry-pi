test -v GIT_LIB && return || readonly GIT_LIB="$(realpath $BASH_SOURCE)"

update-repo-if-older-than() {
    local -r REPO="$1"
    local -r MAX_AGE="$2"
    if older-than $REPO "$MAX_AGE"; then
        local -r BRANCH=$(git -C $REPO symbolic-ref --short HEAD)
        git -C $REPO fetch --depth 1
        git -C $REPO remote -v
        git -C $REPO reset --hard origin/$BRANCH
        git -C $REPO clean -fdx # remove files that are no longer tracked
        touch .
    fi
}
