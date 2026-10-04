# Chapter 2: Where commands run

[Book contents](intro-to-zsh.md) | [Previous: Basic Zsh](ch1.md) | [Next: Giving commands arguments](ch3.md) | [Companion](companion/README.md)

In Chapter 1, `ls` listed files in the current directory. After `cd`, the same command would list different files. The command stayed the same; its surroundings changed.

The directory is one part of a command's context. In this chapter we will also look at variables and the settings a shell reads when it starts.

Start at the repository root, the directory containing `README.md` and `zshrc`. Open a practice shell:

```sh
zsh -f
```

Save the repository's location, then make a temporary place to work:

```zsh
repo=$PWD
tutorial="$PWD/docs/tutorials/zsh"
lab=$(mktemp -d)
mkdir -p "$lab/project/bin" "$lab/functions"
```

`$PWD` contains the current directory's path. `mktemp -d` makes a new temporary directory and prints its name. The `$(...)` captures that output, so `lab` now holds the path. `mkdir -p` also creates any missing parent directories.

We saved `repo` and `tutorial` before changing directories so we can find them again later.

## 1. Find the program a command uses

You can find a program without running it:

```zsh
command -v ls
```

This usually prints a path such as `/bin/ls`. How did Zsh find it? Look at:

```zsh
echo "$PATH"
```

`PATH` is a list of directories separated by colons. For an external command named `ls`, the shell searches these directories in order.

Let's give it a program of our own to find:

```zsh
printf '#!/bin/sh\nprintf "project tool\\n"\n' > "$lab/project/bin/context-tool"
chmod +x "$lab/project/bin/context-tool"
```

The file contains two lines. `#!/bin/sh` says which program should read it. The second line prints `project tool`. `chmod +x` makes the file executable.

We can run it by its full path:

```zsh
"$lab/project/bin/context-tool"
```

It prints `project tool`. To run it by name, put its directory at the front of the search path:

```zsh
cd "$lab/project"
path=("$PWD/bin" "${path[@]}")
command -v context-tool
context-tool
```

Now `command -v` prints the path to our file, and `context-tool` prints its message.

Zsh provides `path`, an array version of `PATH`. The assignment puts our directory first and keeps the existing entries after it. We will study arrays in Chapter 3. For now, the important part is the order. A project tool should not accidentally lose to a different version found earlier in `PATH`.

## 2. Give some commands a name

A function gives a name to a group of commands. Define one with the same name as our program:

```zsh
context-tool() { print -r -- function; }
context-tool
```

This time it prints `function`. The commands between `{` and `}` form the function body. `print -r --` is Zsh's way to print text without interpreting backslash escapes. A function takes precedence over an external program with the same name.

An alias replaces a command word with some text. Try:

```zsh
alias context-tool='print -r -- alias'
context-tool
```

Now it prints `alias`. Ask Zsh to show all the meanings it knows:

```zsh
whence -va context-tool cd
```

You should see the alias, the function, and the executable path. You will also see that `cd` is a builtin, a command implemented by the shell itself.

Remove the extra meanings one at a time:

```zsh
unalias context-tool
context-tool
unfunction context-tool
context-tool
```

These calls print `function`, then `project tool`. Aliases expand before command lookup. For ordinary command lookup, functions come before builtins, which come before external programs. Writing a path such as `./bin/context-tool` selects that file directly.

## 3. See what another shell inherits

A variable in this shell does not automatically appear in a program it starts:

```zsh
unset WS_NOTE
WS_NOTE=parent
zsh -f -c 'echo "child sees: <$WS_NOTE>"'
```

The new shell prints `child sees: <>`. `-c` tells Zsh to run the following string as a command. The single quotes keep our current shell from expanding `$WS_NOTE` before the child sees it.

Export the variable and try again:

```zsh
export WS_NOTE
zsh -f -c 'echo "child sees: <$WS_NOTE>"'
```

Now it prints `child sees: <parent>`. Exported variables make up the environment passed to new programs.

The child can change its copy:

```zsh
zsh -f -c 'WS_NOTE=child; echo "$WS_NOTE"'
echo "$WS_NOTE"
```

These print `child`, then `parent`. The child's assignment did not reach back into the shell that started it.

## 4. Run a file here or in another shell

Save one assignment in a file:

```zsh
printf 'WS_NOTE=from_file\n' > "$lab/settings.zsh"
zsh -f "$lab/settings.zsh"
echo "$WS_NOTE"
```

The output is still `parent`. The new shell read the file and changed its own variable. To run those same commands in our current shell, use `source`:

```zsh
source "$lab/settings.zsh"
echo "$WS_NOTE"
```

Now it prints `from_file`. This is why a file of shell settings is usually sourced.

We can also source a file that defines functions. The book's [workspace helper](examples/workspace.zsh) defines `ws`, which remembers directories by name. Load it and register our project:

```zsh
export WS_HOME="$lab/state"
source "$tutorial/examples/workspace.zsh"
ws add demo "$lab/project"
ws list
```

The list contains `demo` and the project's path. `WS_HOME` tells this example where to save the name, so the record stays in our temporary directory.

First try changing directory inside parentheses:

```zsh
cd "$repo"
( ws go demo; pwd )
pwd
```

The first `pwd` prints the project directory. The second prints the repository directory. Parentheses run commands in a subshell, a copy of the shell with its own state. Its directory change ends with that subshell.

Now run the function directly:

```zsh
ws go demo
pwd
```

This `pwd` prints the project directory. A sourced function runs in the calling shell, so `ws go` can change that shell's directory. Executing a separate script could not do this for its parent.

## 5. Find out which settings a shell reads

Zsh reads different startup files depending on how it starts. An interactive shell accepts commands at a prompt. A login shell also performs login setup. A shell can be both, either, or neither.

Let's make four small startup files that announce their names:

```zsh
mkdir "$lab/startup"
printf 'echo zshenv\n' > "$lab/startup/.zshenv"
printf 'echo zprofile\n' > "$lab/startup/.zprofile"
printf 'echo zshrc\n' > "$lab/startup/.zshrc"
printf 'echo zlogin\n' > "$lab/startup/.zlogin"
ZDOTDIR="$lab/startup" zsh -l -i -c ':'
```

`ZDOTDIR` chooses the directory for user startup files. This assignment applies to the command that follows it. `-l` requests login mode, `-i` requests interactive mode, and `:` is a command that does nothing successfully.

Our files print `zshenv`, `zprofile`, `zshrc`, then `zlogin`. That follows Zsh's startup order:

| When | System file, then user file |
| --- | --- |
| Every invocation | `zshenv`, `$ZDOTDIR/.zshenv` |
| Login | `zprofile`, `$ZDOTDIR/.zprofile` |
| Interactive | `zshrc`, `$ZDOTDIR/.zshrc` |
| Login | `zlogin`, `$ZDOTDIR/.zlogin` |

System-file paths depend on the installation. If `ZDOTDIR` is unset, user files come from `$HOME`.

Try a shell that is neither interactive nor a login shell:

```zsh
ZDOTDIR="$lab/startup" zsh -c ':'
```

Only our `zshenv` file prints. Scripts normally use this mode, so they should not depend on commands in `.zshrc`.

Add `-f`:

```zsh
ZDOTDIR="$lab/startup" zsh -f -c ':'
```

None of our files prints. The system `zshenv` still runs and can change loading options. This is why `-f` is useful for diagnosis without being a completely empty environment.

## 6. Keep a function's temporary settings local

A helper may need its own variables. It should not accidentally overwrite yours:

```zsh
label=outside
show_context() {
  emulate -L zsh
  local label=inside
  setopt noclobber
  echo "$label $options[noclobber]"
}
unsetopt noclobber
show_context
echo "$label $options[noclobber]"
```

Expect `inside on`, then `outside off`. `local` gives the function its own `label`. Other functions it calls can also see that local value until the call ends.

`setopt` turns on a shell option; `unsetopt` turns it off. `noclobber` prevents `>` from overwriting an existing file. `$options[noclobber]` reads that option's current setting.

`emulate -L zsh` gives the function normal Zsh options and restores the caller's options when it returns. It does not undo a `cd` or an assignment to a global variable. Those are separate kinds of state.

## 7. Load a function when it is first needed

You can keep a function's body in a file with the same name. Write this one:

```zsh
cat > "$lab/functions/show_location" <<'ZSH'
pwd
ZSH
```

The `<<'ZSH'` tells the shell to pass the following lines to `cat` until a line containing just `ZSH`. This is a heredoc. Quoting its ending word keeps the body literal. Here we have written a file containing `pwd`.

Tell Zsh where to find it:

```zsh
fpath=("$lab/functions" "${fpath[@]}")
autoload -Uz show_location
show_location
```

The call prints our project directory. `fpath` searches for function files, just as `path` searches for executables. `autoload` waits until the first call to load the body. `-U` prevents alias expansion while loading, and `-z` selects Zsh-style function files.

## Try it yourself

Write `visit NAME` to print a registered workspace's path without leaving the caller in that directory.

Two pieces will help: `$1` is the first argument to a function, and `a && b` runs `b` only if `a` succeeds. Use parentheses to keep the directory change in a subshell.

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

Expect the project path, then the repository path. The missing name produces an error. `$?` reports whether the preceding command succeeded: zero means success, and a nonzero value means failure. The final `pwd` still prints the repository directory.

The useful question is now more precise than "Does this command work?" It is "In which shell, directory, and settings does it work?"

Clean up and leave the practice shell:

```zsh
cd "$repo"
rm -r -- "$lab"
exit
```
