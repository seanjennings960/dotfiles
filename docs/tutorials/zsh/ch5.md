# Chapter 5: Interaction

[Book contents](intro-to-zsh.md) | [Previous: Execution](ch4.md) | [Companion](companion/README.md)

An interactive shell helps you construct commands and observe state. Completion suggests arguments; the workspace function still validates them. Keep these editing conveniences in interactive configuration. Scripts must supply their arguments and check results themselves.

## Start a practice session

Start at the repository root:

```sh
zsh -f
```

`-f` disables normal startup-file loading. Zsh still reads the global `zshenv` if present. Capture the tutorial path before changing directory, and select Emacs bindings explicitly:

```zsh
tutorial=$PWD/docs/tutorials/zsh
bindkey -e
scratch=$(mktemp -d)
export WS_HOME=$scratch/state
mkdir -p "$scratch/practice/project one" "$scratch/practice/project two"
source "$tutorial/examples/workspace.zsh"
cd "$scratch/practice"
ws add one "$PWD/project one"
ws add two "$PWD/project two"
```

Sourcing defines `ws` in this shell, so `ws go NAME` can change its directory.

## Recall and edit

History remembers command text, not the directory or environment that originally gave it meaning. Before rerunning a command, inspect its paths.

```zsh
HISTFILE=$scratch/history
HISTSIZE=1000
SAVEHIST=1000
setopt hist_ignore_dups
bindkey -M emacs '^R'
```

`HISTSIZE` limits in-memory entries; `SAVEHIST` limits saved entries. This session saves history under scratch on exit. `hist_ignore_dups` suppresses consecutive duplicates.

Press Up to recall a command, or Ctrl+R and type `ws add` to search backward. Ctrl+G cancels the search. Ctrl+A and Ctrl+E move to the beginning and end. Edit before pressing Enter. `bindkey` above reports the widget attached to Ctrl+R in the Emacs keymap; another keymap can attach a different action.

## Complete arguments

Initialize the completion system, then source [the interaction example](examples/interaction.zsh):

```zsh
autoload -Uz compinit
compinit -D
source "$tutorial/examples/interaction.zsh"
```

These commands require Zsh's installed completion functions on `fpath`. `compinit` checks those locations and defines `compdef`; `-D` prevents writing a completion dump. The example expects an interactive shell with that initialization already done. Re-sourcing replaces the same functions, registration, and binding.

Type `ws g` and press Tab. Then try `ws go ` followed by Tab. For `ws add third ./`, Tab offers directories. Completion inserts shell quoting when needed, so a directory containing spaces remains one argument. Inspect the resulting text before Enter; manually written paths still need quotes.

Inside `_ws`, `words` contains the command words and `CURRENT` identifies the one under the cursor. `_describe` offers subcommands or saved names; `_files -/` offers directories for `add`. The new name is yours to choose.

Names come from regular files under `${WS_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/zsh-tutorial/workspaces}`. The completion skips hidden temporary files and rejects names outside ASCII letters, digits, underscore, and hyphen. It does not parse `ws list`, which prints names and shell-quoted paths for people. A suggestion can become stale; `ws go` must still validate the saved record and destination.

## Prepare a line with ZLE

ZLE is Zsh's line editor. The example installs this widget:

```zsh
_ws_go_widget() {
  BUFFER='ws go '
  CURSOR=${#BUFFER}
  zle complete-word
}
zle -N ws-go _ws_go_widget
bindkey -M emacs '^Xw' ws-go
```

Press Ctrl+X, release it, then press `w`. This replaces the entire current input with `ws go `, moves the cursor to its end, and invokes completion. Choose a name and inspect the command. Only Enter executes it. `BUFFER` is editable text, not a command to evaluate.

## Observe state in prompts and hooks

Try this optional prompt:

```zsh
setopt prompt_percent
unsetopt prompt_subst
PROMPT='%F{cyan}%n@%m%f %~ %(?.ok.FAIL) %# '
```

`%~` shows the directory and `%(?.ok.FAIL)` reports the previous status. Prompt escapes are interpreted when displayed. They differ from `PROMPT_SUBST`, which enables parameter, command, and arithmetic expansion in the prompt. Single quotes preserve the assignment text; they do not prevent later substitution if you enable that option. `%F` and `%f` provide color without confusing cursor width.

A hook can report directory changes:

```zsh
autoload -Uz add-zsh-hook
tutorial_chpwd() { print -r -- "cwd: $PWD"; }
add-zsh-hook chpwd tutorial_chpwd
```

Registration preserves existing hooks and does not duplicate this function on repeated calls. Use `precmd` for work before each prompt. Both hooks and prompt substitutions add interactive latency. Remove this hook with `add-zsh-hook -d chpwd tutorial_chpwd`.

## Measure the cost

Compare three clean starts with three starts loading completion and the example:

```zsh
for run in {1..3}; do
  /usr/bin/time -p zsh -f -ic exit
done
for run in {1..3}; do
  /usr/bin/time -p zsh -f -ic '
    autoload -Uz compinit
    compinit -D
    source "$1/examples/interaction.zsh"
  ' tutorial "$tutorial"
done
```

Compare the `real` times and their spread. On macOS with Zsh 5.9, three baseline runs rounded to 0.00 seconds; initialized runs took 0.21, 0.19, and 0.16 seconds. Your installed completions and filesystem affect these numbers. These measure initialization, not Tab or prompt redraws.

For optional function-level profiling, load `zsh/zprof` before initialization:

```zsh
zsh -f -ic '
  zmodload zsh/zprof
  autoload -Uz compinit
  compinit -D
  source "$1/examples/interaction.zsh"
  zprof
' tutorial "$tutorial"
```

Its table attributes time to functions. To investigate a slow Tab or hook, load the module in the practice shell, perform that action, then run `zprof`. Measure before adding caching or another plugin.

## Exercise

Register `side project` as `side`. Use the widget to visit it, then report status and directory. What still works without the interaction example?

### Worked solution

```zsh
mkdir -p "$scratch/practice/side project"
ws add side "$scratch/practice/side project"
```

Press Ctrl+X, then `w`, type `si`, press Tab, inspect `ws go side`, and press Enter. Immediately run:

```zsh
print -r -- "status=$? cwd=$PWD"
```

Expect status zero and the `side project` directory. The sourced `ws` still validates input and changes the caller's directory without completion or widgets.

Finish outside scratch and disable its history file before removal:

```zsh
cd "$tutorial"
unset HISTFILE
rm -r -- "$scratch"
exit
```
