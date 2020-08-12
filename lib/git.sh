test -v GIT_LIB && return || readonly GIT_LIB="$(realpath $BASH_SOURCE)"

current-branch() {
    local -r REPO="$1"
    git -C $REPO symbolic-ref --short HEAD
}

fetch-branch() {
    local -r REPO_URL="$1"
    local -r BRANCH="$2"
    local -r MAX_AGE="$3"
    local -r REPO="$4"
    if test -d $REPO; then
        if [ "$(current-branch $REPO)" != "$BRANCH" ]; then
            git -C $REPO fetch --depth 1 origin $BRANCH:$BRANCH
            git -C $REPO checkout --track $BRANCH
            git -C $REPO clean -fdx
        elif older-than $REPO "$MAX_AGE"; then
            git -C $REPO fetch --depth 1 origin $BRANCH
            git -C $REPO reset --hard FETCH_HEAD
            git -C $REPO clean -fd
            touch $REPO
        fi
    else
        git clone --branch $BRANCH --depth 1 $REPO_URL $REPO
    fi
}
