# Source this file in Zsh. ws go must run in the calling shell.
ws() {
  emulate -L zsh
  local LC_ALL=C
  local action=${1-list} name directory record root temporary extra
  local -a records
  local -i fd
  local usage='usage: ws add NAME DIRECTORY | ws list | ws go NAME | ws help'

  case "$action:$#" in
    list:0|list:1|add:3|go:2) ;;
    help:1|-h:1|--help:1) print -r -- "$usage"; return 0 ;;
    *) print -ru2 -- "$usage"; return 2 ;;
  esac

  if [[ $action != list ]]; then
    name=$2
    if [[ -z $name || $name == *[^A-Za-z0-9_-]* ]]; then
      print -ru2 -- 'ws: names must contain only ASCII letters, digits, _ or -'
      return 2
    fi
  fi

  root=${WS_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/zsh-tutorial/workspaces}
  if [[ $root != /* ]]; then
    print -ru2 -- 'ws: the state directory must be absolute; set WS_HOME to an absolute path'
    return 2
  fi

  if [[ $action == add ]]; then
    directory=${3:A}
    if [[ -z $3 || ! -d $directory ]]; then
      print -ru2 -- "ws: not a directory: $3"
      return 1
    fi
    command mkdir -p -- "$root" || return 1
    if [[ -d $root/$name ]]; then
      print -ru2 -- "ws: a directory occupies the record: $name"
      return 1
    fi
    temporary=$(command mktemp "$root/.tmp.XXXXXX") || return 1
    {
      printf '%s\0' "$directory" > "$temporary" || return 1
      command mv -f -- "$temporary" "$root/$name" || return 1
    } always {
      command rm -f -- "$temporary"
    }
    return 0
  fi

  if [[ $action == go ]]; then
    records=("$root/$name")
  else
    if [[ -e $root && ! -d $root ]]; then
      print -ru2 -- "ws: not a state directory: $root"
      return 1
    fi
    records=("$root"/*(N.))
  fi

  for record in "${records[@]}"; do
    name=${record:t}
    [[ $name != *[^A-Za-z0-9_-]* ]] || continue
    if [[ ! -f $record || -L $record ]]; then
      print -ru2 -- "ws: no regular workspace record: $name"
      return 1
    fi
    exec {fd}< "$record" || return 1
    {
      if ! IFS= read -r -d '' directory <&$fd; then
        print -ru2 -- "ws: incomplete workspace record: $name"
        return 1
      fi
      extra=''
      if IFS= read -r -d '' extra <&$fd || [[ -n $extra || $directory != /* ]]; then
        print -ru2 -- "ws: malformed workspace record: $name"
        return 1
      fi
    } always {
      exec {fd}<&-
    }
    if [[ $action == go ]]; then
      builtin cd -- "$directory"
      return $?
    fi
    printf '%s\t%q\n' "$name" "$directory"
  done
}
