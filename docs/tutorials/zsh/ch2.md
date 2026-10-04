# Chapter 2: Context

[Book contents](intro-to-zsh.md) | [Previous: Four concepts](ch1.md) | [Next: Arguments](ch3.md) | [Companion](companion/README.md)

Context determines where a command runs and which state it uses. Start at the repository root in a new practice shell:

```sh
zsh -f
```

`-f` normally skips startup files except the system `zshenv`. It still inherits the parent's environment. Run the following examples in order:

```zsh
repo=$PWD
tutorial="$PWD/docs/tutorials/zsh"
lab=$(mktemp -d)
mkdir -p "$lab/project/bin" "$lab/functions"
```

Save absolute paths before changing directories. This keeps the tutorial reachable after `cd`.

## Find the command

A relative filename starts at the current working directory. A command name without `/` uses command lookup. Aliases expand during parsing; ordinary command lookup then checks functions, builtins, and executables in `PATH`, in that order.

Create a project executable:

```zsh
printf '#!/bin/sh\nprintf "project tool\\n"\n' > "$lab/project/bin/context-tool"
chmod +x "$lab/project/bin/context-tool"
cd "$lab/project"
path=("$PWD/bin" "${path[@]}")
context-tool
```

Expect `project tool`. Zsh ties the `path` array to colon-separated `PATH`. Prepending the project's absolute `bin` gives its executables priority while preserving inherited entries. Startup configuration that puts generic system directories first can hide active project or virtual-environment tools.

Now give the same name other meanings:

```zsh
context-tool() { print -r -- function; }
alias context-tool='print -r -- alias'
whence -va context-tool cd
context-tool
unalias context-tool
context-tool
unfunction context-tool
context-tool
```

`whence -va` shows all matches, including the `cd` builtin. The three calls print `alias`, `function`, then `project tool`. A path such as `./bin/context-tool` directly selects that file.

## State belongs to a shell

Newly executed programs receive only exported variables. They also inherit the working directory, but cannot change their parent's state:

```zsh
unset WS_NOTE
WS_NOTE=practice
zsh -fc 'print -r -- "${WS_NOTE-unset}"'
export WS_NOTE
zsh -fc 'WS_NOTE=child; print -r -- "$WS_NOTE"'
print -r -- "$WS_NOTE"
```

Expect `unset`, `child`, `practice`. `${WS_NOTE-unset}` supplies a fallback when the variable is unset. Zsh's `print -r --` prints without interpreting backslash escapes.

Running `zsh file.zsh` executes a file in another shell. `source file.zsh` executes it in the current shell, so its function definitions remain available. Load the book's [workspace helper](examples/workspace.zsh) this way:

```zsh
export WS_HOME="$lab/state"
source "$tutorial/examples/workspace.zsh"
ws add demo "$lab/project"
ws list
cd "$repo"
( ws go demo; pwd )
pwd
ws go demo
pwd
```

The list contains `demo` with its shell-quoted absolute path. The three `pwd` calls print the project, repository, then project directory. Parentheses run a subshell copy, including unexported variables, so its `cd` cannot change the caller. Sourcing lets `ws go` change your shell directly. `WS_HOME` keeps practice records temporary; `ws help` describes the interface.

## Startup depends on shell mode

Interactive mode enables prompts and terminal conveniences; login mode selects login initialization. These are independent modes. With normal startup loading enabled, Zsh processes these stages in order, checking each system file before its user counterpart:

| When | System file, then user file |
| --- | --- |
| Every invocation | `zshenv`, `$ZDOTDIR/.zshenv` |
| Login | `zprofile`, `$ZDOTDIR/.zprofile` |
| Interactive | `zshrc`, `$ZDOTDIR/.zshrc` |
| Login | `zlogin`, `$ZDOTDIR/.zlogin` |

System paths depend on the installation. If `ZDOTDIR` is unset, Zsh uses `$HOME`. A script normally reads only the first stage, so `.zshrc` is not a script dependency. `-f` disables startup loading except for the system `zshenv`, which can itself change loading options.

Observe user-file loading without editing your configuration:

```zsh
mkdir "$lab/startup"
for file in zshenv zprofile zshrc zlogin; do
  printf 'print -r -- %s\n' "$file" > "$lab/startup/.$file"
done
ZDOTDIR="$lab/startup" zsh -lic ':'
ZDOTDIR="$lab/startup" zsh -c ':'
ZDOTDIR="$lab/startup" zsh -fc ':'
```

The user files print all four names in order, then just `zshenv`, then nothing. `-l` requests login mode, `-i` requests interactive mode, and `-c` runs the supplied command. `:` does nothing successfully.

## Localize helper state

Zsh can load a function on its first call. `fpath` searches function files, separately from executable lookup through `PATH`. Write a file named for the function:

```zsh
cat > "$lab/functions/show_context" <<'ZSH'
emulate -L zsh
local label=inside
setopt nullglob
print -r -- "$label $options[nullglob]"
ZSH
fpath=("$lab/functions" "${fpath[@]}")
autoload -Uz show_context
label=outside
unsetopt nullglob
show_context
print -r -- "$label $options[nullglob]"
```

Expect `inside on`, then `outside off`. `autoload -Uz` prevents alias expansion while loading and selects Zsh-style function files. The quoted heredoc delimiter preserves the function body literally until loading.

`local` limits a variable to the function call, including functions it calls. This is dynamic scope. `emulate -L zsh` selects Zsh behavior and restores the caller's options on return. Here, `nullglob` temporarily permits unmatched filename patterns to disappear. Option localization does not undo `cd` or assignments to global variables.

## Try it yourself

Write `visit NAME` to enter a registered workspace and print its path without changing the caller's directory. Stop if selection fails.

### Worked solution

```zsh
visit() {
  emulate -L zsh
  ( ws go "$1" && pwd )
}
cd "$repo"
visit demo
pwd
visit missing
print -r -- "$?"
pwd
```

Expect the project path, then the repository path. The missing name produces an error and nonzero status; the final directory remains the repository. `&&` runs `pwd` only after successful selection. The subshell contains directory changes.

Clean up and leave the practice shell:

```zsh
cd "$repo"
rm -r -- "$lab"
exit
```
