#!/bin/bash

ROOT=$(cd "$(dirname "$0")" && pwd)

function green { printf "\033[32m$1\033[0m\n"; }
function yellow { printf "\033[33m$1\033[0m\n"; }
function red { printf "\033[31m$1\033[0m\n"; }

# Install a file or directory to a given path by symlinking it, printing nice
# things along the way.
function install {
  local from="$1" to="$2" from_="$ROOT/$1" to_="$HOME/$2"

  if [ ! -e "$from_" ]; then
    red "ERROR: $from doesn't exist! This is an error in $0"
    return 1
  fi

  if [ ! -e "$to_" ]; then
    yellow "Linking ~/$to => $from"

    if [ -d "$from_" ]; then
      ln -s "$from_/" "$to_"
    else
      ln -s "$from_" "$to_"
    fi
  else
    local link
    link=$(readlink "$to_")
    if [ "$?" == 0 -a \( "$link" == "$from_" -o "$link" == "$from_/" \) ]; then
      green "Link ~/$to => $from is already ponies!"
    else
      red "Error linking ~/$to to $from: $to already exists!"
    fi
  fi
}

function install_dot {
  install "$1" ".$1"
}

function ask {
  local question="$1" default_y="$2" yn
  if [ -z "$default_y" ]; then
    read -p "$question (y/N)? "
  else
    read -p "$question (Y/n)? "
  fi
  yn=$(echo "$REPLY" | tr "A-Z" "a-z")
  if [ -z "$default_y" ]; then
    test "$yn" == 'y' -o "$yn" == 'yes'
  else
    test "$yn" == 'n' -o "$yn" == 'no'
  fi
}

# Run the given command under a me-only umask. Useful for atomically creating
# sensitive files and directories.
function umask_mine {
  local old_umask=$(umask) ret
  umask 0077
  "$@"
  ret="$?"
  umask "$old_umask"
  return "$ret"
}

function is_mac { test "$(uname -s)" == "Darwin"; }
function is_linux { test "$(uname -s)" == "Linux"; }

# Try to detect if we're on a server or a personal computer.
function is_server {
  is_mac && return 1
  if is_linux; then
    [ -d /vagrant ] && return 1
    dpkg -l ubuntu-desktop &>/dev/null && return 1
    [[ "$(uname -r)" == *server* ]] && return 0
    [[ "$(uname -r)" == *linode* ]] && return 0
  fi

  red "Couldn't tell if this was a server or desktop, just guessing!"
  return 0
}

cd "$ROOT"
# install all pathogen plugins and update submodules
git submodule init
git submodule update

# Vroom vroom!
# install_dot "gitconfig"
# install_dot "screenrc"
install_dot "tmux.conf"
install_dot "vim"
install_dot "vimrc"
install_dot "bash_aliases"
install "tmux/tmux_neww.sh" "bin/tmux_neww"
#install_dot "oh-my-zsh"
#install_dot "zshrc"
# install_dot "pylintrc"
# intently removed bashrc to protect work files

# The SSH folder most likely already exists, and in any event we don't want to
# manage it ourselves. If we are creating it for the first time, however, we
# should lock down the permissions
# if [ ! -e "$HOME/.ssh" ]; then
#   umask_mine mkdir "$HOME/.ssh"
# fi
# 
# install_dot "ssh/rc"
# 
# # Add some authorized keys
# if [ ! -e $HOME/.ssh/authorized_keys ]; then
#   umask_mine touch "$HOME/.ssh/authorized_keys"
# fi

# Make backup and swp folders
mkdir ~/.vim/.backup
mkdir ~/.vim/.swp
