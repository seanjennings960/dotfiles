# Chapter 5: Working at the prompt

[Book contents](intro-to-zsh.md) | [Previous: Putting commands together](ch4.md) | [Companion](companion/README.md)

So far we have mostly asked what a command does after you press Enter. Now we will look at what the shell can do before that: recall a command, complete a name, or help you edit the line.

We will also make the prompt show where we are and whether the last command succeeded.

## Start a practice session

Start at the repository root:

```sh
zsh -f
```

As before, `-f` skips normal personal startup files, though the system `zshenv` can still run. Keep the following work in this practice shell:

```zsh
repo=$PWD
tutorial=$repo/docs/tutorials/zsh
bindkey -e
lab=$(mktemp -d)
mkdir "$lab/practice"
cd "$lab/practice"
```

`bindkey -e` selects the same Emacs-style editing keys we used in Chapter 1.

## 1. Recall a command instead of retyping it

Run a command you can recognize:

```zsh
echo 'a line to remember'
```

Press Up. The command reappears, ready to edit. You can press Enter to run it again, or Ctrl+C to discard the unfinished input.

For an older command, press Ctrl+R and type `remember`. Zsh searches backward through history. Ctrl+G cancels the search. Ctrl+A and Ctrl+E move to the beginning and end of the command line.

History remembers the text you entered. It does not restore the directory or variables that gave the command its meaning. Check a recalled command before running it somewhere else.

To save this session's history in our temporary directory:

```zsh
HISTFILE=$lab/history
HISTSIZE=1000
SAVEHIST=1000
setopt hist_ignore_dups
```

`HISTSIZE` is the number of entries to keep in memory; `SAVEHIST` is the number to save in `HISTFILE` on exit. `hist_ignore_dups` avoids recording the same command twice in a row.

You can ask what a key does:

```zsh
bindkey -M emacs '^R'
```

Expect `"^R" history-incremental-search-backward`. The keymap connects a key sequence to a named editing action. A different keymap can give the same key a different action.

## 2. Offer words when you press Tab

Zsh can complete more than filenames. To load its completion system, run:

```zsh
autoload -Uz compinit
compinit -D
```

`autoload` works as it did in Chapter 2. This time it loads Zsh's installed `compinit` function through `fpath`. `compinit` sets up completion and checks the function directories. `-D` tells it not to save a completion dump file.

Make a small command:

```zsh
greet() { printf 'Hello, %s\n' "$1"; }
greet Sam
```

It prints `Hello, Sam`. Now give it a completion function:

```zsh
_greet() {
  local -a names=(Sam Alex)
  _describe 'name' names
}
compdef _greet greet
```

`local -a` makes a local array. `_describe` offers its entries as choices. `compdef` tells Zsh to use `_greet` when completing arguments to `greet`.

Type `greet Sa`, then press Tab. The line should become `greet Sam`. Press Enter and the greeting appears.

The completion function suggests names; it does not change `greet` itself. `greet Pat` still works, even though `Pat` was not offered.

## 3. Complete a saved workspace name

Set up two projects for our workspace helper:

```zsh
export WS_HOME=$lab/state
mkdir 'project one' 'project two'
source "$tutorial/examples/workspace.zsh"
ws add one "$PWD/project one"
ws add two "$PWD/project two"
```

The sourced `ws` function can change this shell's directory. It does not yet have its own completion. Add that from [the interaction example](examples/interaction.zsh):

```zsh
source "$tutorial/examples/interaction.zsh"
```

Type `ws g` and press Tab. It completes `go`. After `ws go `, Tab offers `one` and `two`. Type enough of a name to distinguish it, then press Tab again.

For `ws add third ./`, Tab offers directories. If you choose one containing a space, completion inserts the quoting needed to keep it as one argument. Inspect the resulting line before Enter.

The file's `_ws` function uses the same `_describe` mechanism as `_greet`. It also looks at `words`, the command words being edited, and `CURRENT`, the index of the word under the cursor. This lets it offer a subcommand after `ws`, a saved name after `ws go`, or directories after `ws add NAME`.

`_files -/` supplies the directory choices. Saved names come from the registry's regular files, with hidden temporary files and invalid names excluded. The function does not try to recover filenames from the human-readable `ws list` output.

A directory could disappear after completion offers its name. `ws go` must still validate the record when you press Enter. Completion helps enter an argument; it does not prove the operation will succeed.

## 4. Prepare a command with one key sequence

Suppose you often type `ws go `. We can give that editing step a name too. An editing function registered with Zsh's line editor, ZLE, is called a widget.

These are the relevant lines from the file you just sourced:

```zsh
_ws_go_widget() {
  BUFFER='ws go '
  CURSOR=${#BUFFER}
  zle complete-word
}
zle -N ws-go _ws_go_widget
bindkey -M emacs '^Xw' ws-go
```

`BUFFER` holds the line being edited. `${#BUFFER}` is its length, so assigning that value to `CURSOR` moves the cursor to the end. `zle complete-word` asks the existing completion system to continue from there.

`zle -N` registers the widget, and `bindkey` connects it to a key sequence. Press Ctrl+X, release it, then press `w`. The widget replaces your current input with `ws go ` and invokes completion.

Choose a name and inspect the line. Your directory has not changed yet. Only Enter runs the command. This widget edits text; it does not evaluate that text as shell code.

## 5. Let the prompt show where you are

A prompt can answer a question you would otherwise ask with `pwd`:

```zsh
setopt prompt_percent
unsetopt prompt_subst
PROMPT='%~ %# '
```

The next prompt shows your directory. `%~` abbreviates your home directory as `~`, and `%#` supplies the usual prompt character. `PROMPT_PERCENT` enables these percent escapes.

Add an indication of the last command's status:

```zsh
PROMPT='%~ %(?.ok.FAIL) %# '
false
```

The prompt now says `FAIL`. Run `true`, and it says `ok`. `%(?.ok.FAIL)` chooses between the two words based on the previous exit status.

You can add color with `%F{cyan}` and return to the normal color with `%f`. Zsh understands the width of its own color escapes, which helps it position the cursor correctly.

Prompt escapes differ from `PROMPT_SUBST`. That option enables variable, command, and arithmetic expansion whenever the prompt is displayed. We left it off here. Single quotes preserve the assignment text, but would not prevent later expansion if you enabled that option.

## 6. Run a function after changing directory

A hook is a function that Zsh calls at a particular moment. For example, `chpwd` hooks run after a directory change:

```zsh
autoload -Uz add-zsh-hook
tutorial_chpwd() { print -r -- "cwd: $PWD"; }
add-zsh-hook chpwd tutorial_chpwd
cd "$lab/practice/project two"
```

The directory change prints a line beginning with `cwd:`, followed by the new path. `add-zsh-hook` adds our function without replacing other registered hooks. Adding the same function again does not duplicate it.

Remove the hook when you no longer want the extra output:

```zsh
add-zsh-hook -d chpwd tutorial_chpwd
```

Use a `precmd` hook instead for work that belongs before each prompt. Choose the event you need, since a slow function called on every prompt can make the terminal feel slow even when no command is running.

## 7. Measure before adding more settings

We have added completion and a widget. How much time does loading them take?

First measure three starts without personal configuration:

```zsh
for run in {1..3}; do
  /usr/bin/time -p zsh -f -ic exit
done
```

Then measure three starts that initialize completion and load the example:

```zsh
for run in {1..3}; do
  /usr/bin/time -p zsh -f -ic '
    autoload -Uz compinit
    compinit -D
    source "$1/examples/interaction.zsh"
  ' tutorial "$tutorial"
done
```

`/usr/bin/time -p` reports elapsed seconds on its `real` line. Compare several runs because filesystem caches and other work on the machine affect the result. These commands measure initialization, not the time taken by a later Tab press.

In the second command, `tutorial` supplies a name for the new shell's `$0`, and the following path becomes its `$1`. That is how the child finds our file without relying on the current directory.

If initialization is slow, ask which functions used the time. Zsh has a profiling module for this:

```zsh
zsh -f -ic '
  zmodload zsh/zprof
  autoload -Uz compinit
  compinit -D
  source "$1/examples/interaction.zsh"
  zprof
' tutorial "$tutorial"
```

`zmodload` loads the module; `zprof` prints its measurements. Loading the module before `compinit` lets it measure those function calls.

For a slow Tab or hook, load `zsh/zprof` in the practice shell, perform the action, then run `zprof` there. This gives you a particular function to investigate instead of guessing which plugin is expensive.

## Try it yourself

Make a directory named `side project` and register it as `side`. Use the widget to visit it. Check both the command's status and the resulting directory.

Which part of this operation would still work if you had never loaded the interaction example?

### Worked solution

```zsh
mkdir -p "$lab/practice/side project"
ws add side "$lab/practice/side project"
```

Press Ctrl+X, then `w`, type `si`, press Tab, inspect `ws go side`, and press Enter. Immediately run:

```zsh
print -r -- "status=$? cwd=$PWD"
```

Expect status zero and the path ending in `side project`. You could still type `ws go side` yourself without the widget or completion. The sourced `ws` function does the directory change; the interactive settings help you enter the request.

Finish outside the temporary directory. Unset `HISTFILE` first so the shell does not try to save history into a directory we have removed:

```zsh
cd "$repo"
unset HISTFILE
rm -r -- "$lab"
exit
```

You can now follow a command from the line you edit to the arguments a program receives and the result it returns. Use the same small experiments when a command from an agent, a plugin, or your own configuration does something unexpected.
