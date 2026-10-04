# Workspace example

Give a project directory a short name, then use that name to return to it. That is
what `ws` does. The [Zsh book](../intro-to-zsh.md) uses this function to explain how
commands receive arguments and change shell state.

From the repository root, start `zsh -f`, then run:

```zsh
tutorial=$PWD/docs/tutorials/zsh
lab=$(mktemp -d)
export WS_HOME=$lab/state
mkdir "$lab/project one"
source "$tutorial/examples/workspace.zsh"
```

The last command loads the function into this shell. Give the new directory the
name `demo`:

```zsh
ws add demo "$lab/project one"
```

There is no output on success. List the saved names:

```zsh
ws list
```

You should see `demo` and the directory's path. Enter that directory by name:

```zsh
ws go demo
pwd
```

The printed path ends in `project one`. `ws go` calls `cd` in your current shell,
which is why we sourced the function rather than running it as a separate script.

`ws help` shows the available commands. Bare `ws` lists entries.
`ws add NAME DIRECTORY` requires an existing directory and a nonempty name
containing only ASCII letters, digits,
`_`, or `-`. It stores the resolved absolute directory, including spaces or
newlines. `ws list` quotes paths for display; it is not a machine-readable protocol.
`ws go NAME` reads and validates the record before calling `cd` in your shell.
Failed selection preserves the current directory.

## How a name is saved

The registry defaults to
`${WS_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/zsh-tutorial/workspaces}`.
Use an absolute state path so changing directory does not select another registry.
Sourcing the file does not create state or change your options. Each entry contains
one absolute path followed by NUL. A temporary file beside the destination and a
rename publish a whole record; repeated registration replaces that name. The last
successful writer wins. Failed writes remove their own temporary files. A process
killed without cleanup can leave a hidden temporary file, which listing ignores.

## Complete a name with Tab

Load the optional completion and editing functions in this practice shell:

```zsh
bindkey -e
autoload -Uz compinit
compinit -D
source "$tutorial/examples/interaction.zsh"
```

Type `ws go d` and press Tab. The name should complete to `demo`. Press Enter to
run the command.

You can also press Ctrl+X, release it, then press `w`. This widget replaces your
current input with `ws go ` and offers completion. It waits for Enter before
executing the command. See [Chapter 5](../ch5.md) for how this works.

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
