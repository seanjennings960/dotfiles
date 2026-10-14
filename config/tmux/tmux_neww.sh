#!/bin/bash
# pane=$(echo "$1" | tr -d '%')


usage() {
    echo "Usage: $0 [-v/-h/-w] <pane_id>" 1>&2; exit 1;
}

count=0
while getopts ":v:h:w:" opt; do
    case ${opt} in
        h)
            ((count++))
            pane_id=${OPTARG}
            command="tmux split-window -h"
            ;;
        v)
            ((count++))
            pane_id=${OPTARG}
            command="tmux split-window -v"
            ;;
        w)
            ((count++))
            pane_id=${OPTARG}
            command="tmux neww"
            ;;
        *)
            echo no args
            usage
            ;;
    esac
done

if [ ${count} != 1 ]; then
    echo "Can only take 1 of -v, -h, and -w"
    usage
fi

pane_path=$(tmux show-environment TMUX_"${pane_id}"_PATH | sed 's/^[^=]*=//g')
if [ -z "${pane_path}" ]; then
    usage
fi

# echo Setting pane path: "$pane_path"
tmux set-environment NEWW "$pane_path"
# echo Command: ${command}
${command}