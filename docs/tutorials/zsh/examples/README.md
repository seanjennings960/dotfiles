# Workspace example

The [Zsh book](../intro-to-zsh.md) develops one sourced function, `ws`, across its
four concepts. It registers directories and changes the calling shell's directory.

From the repository root, start `zsh -f`, then run:

```zsh
tutorial=$PWD/docs/tutorials/zsh
lab=$(mktemp -d)
export WS_HOME=$lab/state
mkdir "$lab/project one"
source "$tutorial/examples/workspace.zsh"
ws add demo "$lab/project one"
ws list
ws go demo
pwd
```

`ws help` prints usage. Bare `ws` lists entries. `ws add NAME DIRECTORY` requires
an existing directory and a nonempty name containing only ASCII letters, digits,
`_`, or `-`. It stores the resolved absolute directory, including spaces or
newlines. `ws list` quotes paths for display; it is not a machine-readable protocol.
`ws go NAME` reads and validates the record before calling `cd` in your shell.
Failed selection preserves the current directory.

The registry defaults to
`${WS_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/zsh-tutorial/workspaces}`.
Use an absolute state path so changing directory does not select another registry.
Sourcing the file does not create state or change your options. Each entry contains
one absolute path followed by NUL. A temporary file beside the destination and a
rename publish a whole record; repeated registration replaces that name. The last
successful writer wins. Failed writes remove their own temporary files. A process
killed without cleanup can leave a hidden temporary file, which listing ignores.

For completion and the Ctrl+X, then `w` widget in this practice shell:

```zsh
bindkey -e
autoload -Uz compinit
compinit -D
source "$tutorial/examples/interaction.zsh"
```

The widget replaces current input with `ws go ` and offers completion. Press Enter
to execute the completed command. See [Chapter 5](../ch5.md) for prompts, hooks,
and profiling. These interactive settings are separate from `ws` itself.

Clean up from outside the practice directory:

```zsh
cd "$tutorial"
rm -r -- "$lab"
exit
```

## Check

From the repository root, with Python 3.9+ and Zsh available:

```sh
python3 -m unittest discover -s docs/tutorials/zsh/examples -p 'test_*.py'
```

The checks use disposable homes and registries. They cover exact path storage,
calling-shell state, invalid records, and failed publication preserving prior data.
