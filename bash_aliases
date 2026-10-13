#!/bin/bash
# Shared Bash/Zsh personal settings, also safe to source directly.
case $- in *i*) ;; *) return ;; esac

alias vim='nvim'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Append defaults: an activated project's bin must stay first.
case :${PATH}: in
    *:"$HOME/bin":*) ;;
    *) export PATH="${PATH:+$PATH:}$HOME/bin" ;;
esac

_dotfiles_tmux_path() {
    # An inherited pane id alone is not a session. Never query tmux for it.
    if [[ -n ${TMUX:-} && ${TMUX_PANE:-} == %* ]] && command -v tmux >/dev/null 2>&1; then
        command tmux set-environment -g "TMUX_${TMUX_PANE}_PATH" "$PWD" 2>/dev/null || :
    fi
    return 0
}

if [[ -n ${BASH_VERSION:-} ]]; then
    # Function syntax avoids alias expansion when this file is sourced again.
    function cd {
        builtin cd "$@" || return $?
        _dotfiles_tmux_path
    }
elif [[ -n ${ZSH_VERSION:-} ]]; then
    autoload -Uz add-zsh-hook
    add-zsh-hook -d chpwd _dotfiles_tmux_path
    add-zsh-hook chpwd _dotfiles_tmux_path
fi

# This variable is handed to a single new pane via tmux -e, not server-global.
if [[ ${DOTFILES_START_DIR+x} ]]; then
    if [[ -n $DOTFILES_START_DIR ]]; then
        builtin cd -- "$DOTFILES_START_DIR" || :
    fi
    unset DOTFILES_START_DIR
fi
_dotfiles_tmux_path
