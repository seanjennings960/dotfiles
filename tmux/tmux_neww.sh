#!/bin/bash
# Create from one pane's logical directory without a shared startup handoff.
set -eu

usage() {
    printf 'Usage: %s {-h|-v|-w} %%pane_id\n' "$0" >&2
    exit 1
}

[[ $# == 2 ]] || usage
case $1 in
    -h|-v|-w) mode=$1 ;;
    *) usage ;;
esac
pane_id=$2
[[ $pane_id =~ ^%[0-9]+$ ]] || usage

# Resolve the requested pane before consulting its key; invalid targets fail.
physical_path=$(tmux display-message -p -t "$pane_id" '#{pane_current_path}')
path=$physical_path
key="TMUX_${pane_id}_PATH"
if entry=$(tmux show-environment -g "$key" 2>/dev/null); then
    logical_path=${entry#"$key="}
    if [[ $entry == "$key="* && $logical_path == /* && -d $logical_path ]]; then
        path=$logical_path
    fi
fi
[[ $path == /* && -d $path ]] || {
    printf 'No usable directory for pane %s\n' "$pane_id" >&2
    exit 1
}

# -c establishes a usable physical cwd; the shell consumes the child-only -e
# value with builtin cd to restore logical $PWD, then unsets it. No eval.
if [[ $mode == -w ]]; then
    session_id=$(tmux display-message -p -t "$pane_id" '#{session_id}')
    exec tmux new-window -t "$session_id:" -c "$path" -e "DOTFILES_START_DIR=$path"
else
    exec tmux split-window "$mode" -t "$pane_id" -c "$path" -e "DOTFILES_START_DIR=$path"
fi
