#!/bin/bash

DOTFILES="$(dirname -- "$(readlink -f "${BASH_SOURCE}")")"
NVIM_DIR="${HOME}/.config/nvim"

function install_nvim {
    ln -s "${DOTFILES}"/nvim "${NVIM_DIR}"
}

install_nvim
