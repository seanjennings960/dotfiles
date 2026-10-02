# shellcheck shell=bash
# Personal interactive snippet; source from the managed ~/.bashrc block.
case $- in *i*) ;; *) return ;; esac

HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend checkwinsize

# Resolve the checkout even when activation links this file into XDG config.
_dotfiles_source=$(realpath -- "${BASH_SOURCE[0]}" 2>/dev/null) ||
    _dotfiles_source=$(readlink -f -- "${BASH_SOURCE[0]}" 2>/dev/null)
if [[ -n $_dotfiles_source ]]; then
    # shellcheck source=bash_aliases
    source "${_dotfiles_source%/*}/bash_aliases"
fi
unset _dotfiles_source

# Use the distribution's completion (including its lazy Git loader) once.
if ! shopt -oq posix && [[ -z ${BASH_COMPLETION_VERSINFO:-} ]]; then
    if [[ -r /usr/share/bash-completion/bash_completion ]]; then
        # shellcheck source=/dev/null
        source /usr/share/bash-completion/bash_completion
    elif [[ -r /etc/bash_completion ]]; then
        # shellcheck source=/dev/null
        source /etc/bash_completion
    fi
fi

if [[ -z ${_DOTFILES_BASH_LOCAL_LOADED:-} ]]; then
    _DOTFILES_BASH_LOCAL_LOADED=1
    if [[ -r ${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/local.bash ]]; then
        # shellcheck source=/dev/null
        source "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/local.bash"
    fi
fi
