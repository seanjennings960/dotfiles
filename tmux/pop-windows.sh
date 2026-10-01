#!/bin/bash

usage() {
    echo "Usage: pop-windows [-t pane] [-c client] <window-index>..." 1>&2
    exit 2
}

fail() {
    local message="$1"

    echo "pop-windows: ${message}" 1>&2
    if [ -n "${TMUX:-}" ]; then
        tmux display-message "pop-windows: ${message}" 2>/dev/null || true
    fi
    exit 1
}

target_pane=""
target_client=""

while getopts ":t:c:h" opt; do
    case "${opt}" in
        t)
            target_pane="${OPTARG}"
            ;;
        c)
            target_client="${OPTARG}"
            ;;
        h)
            usage
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND - 1))

if [ "$#" -eq 0 ]; then
    fail "provide at least one window index"
fi

if [ -n "${target_pane}" ]; then
    source_session=$(tmux display-message -p -t "${target_pane}" '#{session_id}' 2>/dev/null) ||
        fail "could not find pane ${target_pane}"
else
    source_session=$(tmux display-message -p '#{session_id}' 2>/dev/null) ||
        fail "could not determine the current tmux session"
fi

if [ -z "${target_client}" ]; then
    target_client=$(tmux display-message -p '#{client_name}' 2>/dev/null || true)
fi

requested_windows="$*"
window_ids=()
window_indexes=()

# Resolve every index before moving anything; moving a window may renumber the rest.
for window_index in "$@"; do
    case "${window_index}" in
        ""|*[!0-9]*)
            fail "invalid window index: ${window_index}"
            ;;
    esac

    window_id=$(tmux display-message -p -t "${source_session}:${window_index}" '#{window_id}' 2>/dev/null) ||
        fail "window ${window_index} does not exist in the current session"

    for existing_id in "${window_ids[@]}"; do
        if [ "${window_id}" = "${existing_id}" ]; then
            fail "window ${window_index} was requested more than once"
        fi
    done

    window_ids+=("${window_id}")
    window_indexes+=("${window_index}")
done

destination_session=$(tmux new-session -dP -F '#{session_id}' 2>/dev/null) ||
    fail "could not create a new session"
destination_name=$(tmux display-message -p -t "${destination_session}" '#{session_name}')
placeholder_window=$(tmux display-message -p -t "${destination_session}" '#{window_id}')

# Switch first so the source session can safely disappear when all of its windows move.
if [ -n "${target_client}" ] &&
    ! tmux switch-client -c "${target_client}" -t "${destination_session}"; then
    tmux kill-session -t "${destination_session}"
    fail "could not switch client ${target_client} to the new session"
fi

for ((i = 0; i < ${#window_ids[@]}; i++)); do
    if ! tmux move-window -k -s "${window_ids[$i]}" \
        -t "${destination_session}:${window_indexes[$i]}"; then
        fail "could not move window ${window_indexes[$i]} to session ${destination_name}"
    fi
done

# The first move may already have replaced the new session's placeholder window.
tmux kill-window -t "${placeholder_window}" 2>/dev/null || true
tmux select-window -t "${window_ids[0]}"
tmux display-message -t "${window_ids[0]}" \
    "Moved windows ${requested_windows} to session ${destination_name}"
