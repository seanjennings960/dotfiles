#!/bin/bash

# CURR_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
# source "${CURR_DIR}"/activate

alias vim="XDG_DATA_HOME=$NVIM_DIR/share XDG_CONFIG_HOME=$NVIM_DIR nvim"


# export ANDROID_SDK_ROOT=$HOME/Library/Android/Sdk
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_SDK_ROOT/emulator
export PATH=$PATH:$ANDROID_SDK_ROOT/platform-tools

# We do some magic here to make sure that when we open up new pains
# in tmux, symbolic links are not dereferenced. To achieve this, we:
# 1. maintain the symbolic link as a tmux environment variable
#    for each pane.
# 2. Right before we create a new pane/window, we set the NEWW envvar
#    in the tmux_neww.sh script.
# 3. We bind new-pane and new-window commands to run the tmux_neww.sh script.
# NOTE: the tmux_neww script must be in $PATH for tmux to run it. For some
# reason, just calling the absolute path returns an sh 127 error that
# "command not found"

# Set the pane ID variable when we start a new shell,
# and update the TMUX_${pane_id}_PATH each time we cd.
export pane_id=$(tmux display-message -p "#{pane_id}")
function cd_with_path() {
    cd "$@"
    tmux set-environment TMUX_"${pane_id}"_PATH "$(pwd)"
}
alias cd="cd_with_path"

# Whenever the NEWW tmux environment variable is set, cd into
# that directory.
neww=$(tmux show-environment NEWW 2> /dev/null | sed 's/^[^=]*=//')
if [ "$neww" != "-NEWW" ] && [ "$neww" != "" ] ; then
    cd "$neww";
else
    # This cd is called when we enter the shell through means
    # other than the tmuw_neww.sh script, i.e. when
    # creating a new tmux session via the ``tmux`` command.
    # This makes sure that TMUX_${pane_id}_PATH # is always set.
    # Unfortunately, symbolic links still aren't honored in this case.
    cd "$(pwd)"
fi
tmux set-environment -r NEWW