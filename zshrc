# Personal interactive snippet; Bash remains the default pending evaluation.
[[ -o interactive ]] || return

# :A resolves activation symlinks; :h selects the real repository directory.
_dotfiles_root=${${(%):-%x}:A:h}
source "$_dotfiles_root/bash_aliases"

HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
HISTSIZE=1000
SAVEHIST=2000
setopt APPEND_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

if [[ -z ${_DOTFILES_ZSH_LOADED:-} ]]; then
    _DOTFILES_ZSH_LOADED=1
    autoload -Uz compinit
    compinit
    # Explicit Tab binding works without a framework or user keymap.
    bindkey '^I' expand-or-complete
    if [[ -r ${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/local.zsh ]]; then
        source "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/local.zsh"
    fi
    # Opt in locally. Use the repository's existing pinned submodules only.
    if [[ ${DOTFILES_USE_OH_MY_ZSH:-0} == 1 && -r $_dotfiles_root/oh-my-zsh/oh-my-zsh.sh ]]; then
        ZSH=$_dotfiles_root/oh-my-zsh
        ZSH_CUSTOM=$_dotfiles_root/zsh
        zstyle ':omz:update' mode disabled
        DISABLE_AUTO_UPDATE=true
        ZSH_THEME=amuse
        plugins=(git)
        [[ -r $ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh ]] &&
            plugins+=(zsh-autosuggestions)
        source "$ZSH/oh-my-zsh.sh"
    fi
fi
unset _dotfiles_root
