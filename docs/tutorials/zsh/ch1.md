# Chapter 1: Zsh in four concepts

[Book contents](intro-to-zsh.md)

Zsh interprets commands and runs programs. Start a session without your usual startup files:

```sh
zsh -f
```

Zsh comes with modern macOS and this repo's devcontainer. Run each line below in that shell. Omit any `%` or `$` prompt prefix; `exit` returns to your previous shell.

## 1. Context

Commands use a working directory and environment. Create a practice directory, choosing an unused name:

```zsh
cd ~
mkdir zsh-practice
cd zsh-practice
pwd
ls -la
```

`cd` changes directory, `mkdir` creates one, and `pwd` prints its path. `ls -la` lists details, including hidden files.

Absolute paths start with `/`; relative paths start from the current directory. `~` means home, `..` means parent, and `cd -` returns to the previous directory.

Variables hold values. `HOME` names your home directory; `PATH` lists executable search directories. `$` reads a variable; `export` passes it to child programs:

```zsh
echo "$HOME"
echo "$PATH"
command -v zsh
export MY_SETTING="enabled"
```

`echo` prints its arguments. `command -v` shows how a command name resolves.

## 2. Arguments

Spaces separate arguments; quotes keep them together:

```zsh
touch notes.txt "my notes.txt"
ls -l "my notes.txt"
```

`touch` creates missing files. The second command runs `ls` with option `-l` and one filename argument.

`cp` copies, `mv` moves or renames, and `rm` deletes without using the Trash:

```zsh
cp notes.txt backup.txt
mv backup.txt old-notes.txt
rm old-notes.txt
```

Assignments have no spaces around `=`. Double quotes allow expansion; single quotes preserve literal text:

```zsh
name="Sam"
echo "Hello, $name"
echo 'Hello, $name'
```

The two outputs are `Hello, Sam` and `Hello, $name`.

Wildcards also construct arguments:

```zsh
ls *.txt
echo "*.txt"
```

Unquoted `*.txt` becomes matching filenames before `ls` runs; quoted `"*.txt"` stays literal. `*` matches any sequence of characters within a filename; `?` matches one. By default, globbing excludes leading dots and errors if nothing matches.

## 3. Execution

Programs have input, output, and error streams. A pipe connects one program's standard output to another's standard input:

```zsh
printf 'pear\napple\nbanana\n' > fruit.txt
cat fruit.txt
sort fruit.txt | wc -l
```

`printf` turns `\n` into newlines; `cat` displays the file. `sort` orders lines, and `wc -l` counts them, giving `3`.

| Operator | Effect |
| --- | --- |
| `> file` | Write standard output to a file, creating or overwriting it. |
| `>> file` | Append standard output to a file. |
| `< file` | Read standard input from a file. |
| `2> file` | Write standard error to a file. |

```zsh
sort fruit.txt > sorted-fruit.txt
printf 'orange\n' >> fruit.txt
wc -l < fruit.txt
```

The count is now `4`. Exit status is separate from output. Zero means success; a nonzero status indicates failure. `$?` reads the most recent status:

```zsh
false
echo "$?"
false | true
echo "$?"
```

`false` fails and `true` succeeds. These print `1` then `0`. By default, a pipeline reports only its last command's status.

## 4. Interaction

Use Emacs-style line-editor bindings so these shortcuts behave consistently:

```zsh
bindkey -e
```

| Key | Action |
| --- | --- |
| Tab | Complete a command or filename. Try `ls no` to complete `notes.txt`. |
| Up arrow | Recall a previous command. |
| Ctrl+R | Search command history as you type. |
| Ctrl+A / Ctrl+E | Move to the beginning or end of the line. |
| Ctrl+C | Cancel the current input or usually interrupt a running program. |

## Try it yourself

Copy `fruit.txt` to `shopping list.txt`, append `grape`, and predict the new line count. Use history to recall the counting command.

### Worked solution

```zsh
cp fruit.txt "shopping list.txt"
printf 'grape\n' >> "shopping list.txt"
wc -l < "shopping list.txt"
```

Expect `5`. Quotes preserve filename spaces. `<` opens the file as input, so `wc` receives only `-l` as an argument.
