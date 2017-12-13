#!/bin/bash

command -v fswatch >/dev/null 2>&1 || { echo >&2 "fswatch is not installed. To install it use 'brew install fswatch'. Aborting."; exit 1; }
command -v mix >/dev/null 2>&1 || { echo >&2 "mix is not installed. Aborting."; exit 1; }

PROJECT_PATH=$(git rev-parse --show-toplevel)
[[ "$?" != "0" ]] && echo "Stale test watch works only within git project." && exit 1;

declare -a IGNORED_PATHS
declare -i throttle_by=2

# Ignore all paths from gitignore and ~/.gitignore_global
IGNORED_PATHS+=('.git' '_build' 'docs' 'deps' 'cover')

function read_gitignore() {
  while IFS='' read -r line || [[ -n "$line" ]]; do
    IGNORE_PATH=${line%%#*}
    if [[ "${IGNORE_PATH}" != "" ]]; then
      IGNORED_PATHS=("${IGNORED_PATHS[@]}" ${IGNORE_PATH})
    fi
  done < "$1"
}

[ -f "${PROJECT_PATH}/.gitignore" ] && read_gitignore "${PROJECT_PATH}/.gitignore"
[ -f "$HOME/.gitignore_global" ] && read_gitignore "$HOME/.gitignore_global"

function filter_ignored_paths() {
  while read match; do
    local changes_detected=1
    for e in "${IGNORED_PATHS[@]}"; do
      [[ "$match" == "${PROJECT_PATH}/$e"* || "$match" == *"$e" ]] && changes_detected="0" && break;
    done

    [[ "${changes_detected}" == "1" ]] && echo "Changes detected in $match";
  done
}

ARGS="$@"
[[ "${ARGS}" == "" ]] && ARGS="--stale"

fswatch $PWD | filter_ignored_paths | mix test --trace --no-start --compile --listen-on-stdin ${ARGS}
