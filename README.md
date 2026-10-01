# Rahul Rawat's Dotfiles

A collection of the dotfiles used on my work and home Linux machines.

Prerequisites:
```
sudo apt-get install tmux
sudo apt-get install vim
sudo apt-get isntall zsh
```

To use the dotfiles:
```bash
cd
git clone https://github.com/rahulraw/dotfiles.git
cd dotfiles 
./infectdots.sh
submodule update --init --recursive
```

This install script does the following things: 
* Link .* (dotfiles) on your computer to this directory
* Initialize and update git submodules for pathogen plugins

### OpenCode

The installer links `opencode/` to `~/.config/opencode`, making its config,
agents, commands, plugins, and skills available to every OpenCode session.
OpenCode writes JavaScript dependency state into this directory at startup;
`package.json`, lockfiles, and `node_modules/` are generated and intentionally
ignored by Git.

OpenCode stores its executable under `~/.opencode` and credentials and session
state outside `~/.config/opencode`. Those locations are not managed by this
repository. Restart OpenCode after changing global config or skills.

To install xclip (allows your tmux buffer to sync with the system buffer):
```bash
sudo apt-get install --assume-yes xclip
```

To install YouCompleteMe:
```bash
cd ~/.vim/bundle/YouCompleteMe
./install.py --all
```

## Development container

The devcontainer provides Ubuntu 24.04 with Git, Vim, tmux, Zsh, and ShellCheck.
It uses the non-root `vscode` user with sudo access and Bash as the default
VS Code terminal. Dotfile activation is manual, so you can choose which
configurations to try inside the container.

1. Install and start Docker (Docker Desktop on macOS or Windows).
2. Install VS Code and the **Dev Containers** extension
   (`ms-vscode-remote.remote-containers`).
3. Open this repository in VS Code, then run **Dev Containers: Reopen in
   Container** from the command palette. The first launch builds the image.

Alternatively, with the Dev Containers CLI installed, run from the repository
root:

```bash
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . bash
```

The repository is mounted into the container, so workspace edits persist on the
host. Changes elsewhere in the container, including manually installed packages
and home-directory configuration, can be lost when it is rebuilt.

To add persistent system tools, edit `.devcontainer/Dockerfile`. After changing
the Dockerfile or `.devcontainer/devcontainer.json`, run **Dev Containers:
Rebuild Container** from the VS Code command palette.

### Known Issues

* Powerline does not always work as intended. Look through the Powerline installation
guide on github

* Powerline will show weird icons by default in the powerline bar. Set the powerline 
mapping to 0 to fix this.

* If there is errors involving a "vim error" due to comments in the vimrc, restarting
your computer can fix the problems. Thanks Linus! 

### Future Improvements
* Transition to Vundle from Pathogen  
Pathogen way to version control utilized git submodules. Vundle requires 
plugin calls in your vimrc files which is a little more elegant.

* Transition to Antigen from Oh-my-zsh   
Antigen is built with inspiration of oh-my-zsh and pathogen. However, it 
is tries to avoid the bloat of oh-my-zsh using Vundle inspired plugin calls.

* Fix autosuggestions bug

* ALE not working in new setups

* Uses Powerline by default
Find way to set powerline setting if available
