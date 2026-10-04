# Source in an interactive Zsh after: autoload -Uz compinit; compinit -D
# Registers ws completion and binds Ctrl+X, then w in the Emacs keymap.
if [[ ! -o interactive ]] || (( ! $+functions[compdef] )); then
  print -u2 -- 'interaction.zsh: source in an interactive shell after compinit'
  return 1
fi

_ws() {
  local -a commands names
  local root record name
  local LC_ALL=C

  if (( CURRENT == 2 )); then
    commands=(
      'add:register a directory'
      'list:list workspaces'
      'go:change directory'
      'help:show usage'
    )
    _describe 'workspace command' commands
    return
  fi

  case $words[2] in
    add)
      case $CURRENT in
        3) _message 'new name: ASCII letters, digits, underscore or hyphen' ;;
        4) _files -/ ;;
        *) return 1 ;;
      esac
      ;;
    go)
      (( CURRENT == 3 )) || return 1
      root=${WS_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/zsh-tutorial/workspaces}
      for record in "$root"/*(N.); do
        name=${record:t}
        [[ -n $name && $name != *[^A-Za-z0-9_-]* ]] || continue
        names+=("$name")
      done
      _describe 'workspace' names
      ;;
    *) return 1 ;;
  esac
}

_ws_go_widget() {
  BUFFER='ws go '
  CURSOR=${#BUFFER}
  zle complete-word
}

compdef _ws ws
zle -N ws-go _ws_go_widget
bindkey -M emacs '^Xw' ws-go
