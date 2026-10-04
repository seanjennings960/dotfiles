# Chapter 1: Basic Zsh

[Book contents](intro-to-zsh.md)

Zsh is a shell: it reads your commands, runs programs, and lets you combine them. It's the default shell on modern macOS.

Here's a hands-on introduction. Type commands into your terminal and press **Enter**. If your prompt ends in `%` or `$`, don't type that symbol.

## 1. Move around directories

Your shell always has a **current directory**. Commands often operate on files in that directory.

```zsh
pwd
```

Prints the current directory's full path.

```zsh
ls
```

Lists what's inside it. You can add options:

```zsh
ls -l
```

Shows details such as permissions, size, and modification time.

```zsh
ls -a
```

Includes hidden files, whose names start with a dot.

Use `cd` to change directories:

```zsh
cd Documents
```

Some useful shortcuts:

| Command | Meaning |
|---|---|
| `cd ..` | Move to the parent directory |
| `cd ~` | Move to your home directory |
| `cd` | Also move to your home directory |
| `cd -` | Return to your previous directory |

A path starting with `/` is an **absolute path**, such as `/Users/sam/Documents`. A path without a leading `/` is usually relative to your current directory.

## 2. Create a practice directory

Run:

```zsh
cd ~
mkdir zsh-practice
cd zsh-practice
```

`mkdir` creates a directory. You're now working inside `zsh-practice`.

Create an empty file:

```zsh
touch notes.txt
ls
```

Copy and rename it:

```zsh
cp notes.txt backup.txt
mv backup.txt old-notes.txt
ls
```

- `cp` copies a file.
- `mv` moves or renames it.
- `rm` removes it.

To remove the practice copy:

```zsh
rm old-notes.txt
```

`rm` deletes directly rather than moving files to the Trash.

## 3. Understand commands and arguments

A typical command looks like:

```text
command option argument
```

For example:

```zsh
ls -l notes.txt
```

- `ls` is the command.
- `-l` is an option that changes its behavior.
- `notes.txt` is the file to operate on.

Spaces separate arguments. To keep a filename containing spaces together, quote it:

```zsh
touch "my notes.txt"
ls -l "my notes.txt"
```

Without quotes, `my notes.txt` would be two arguments.

## 4. Use completion and history

These make everyday shell use much easier:

- **Tab** completes commands and filenames. Type `ls no` and press Tab to complete `notes.txt`.
- **Up arrow** recalls previous commands.
- **Ctrl+R** searches your command history. Type part of a previous command.
- **Ctrl+A** moves to the beginning of the command line.
- **Ctrl+E** moves to the end.
- **Ctrl+C** cancels the current command or usually stops the running program.

## 5. Use variables and quotes

Assign a variable with no spaces around `=`:

```zsh
name="Sam"
```

Read its value with `$name`:

```zsh
echo "$name"
```

`echo` prints its arguments.

Double quotes allow variable expansion:

```zsh
echo "Hello, $name"
```

Output:

```text
Hello, Sam
```

Single quotes keep the text literal:

```zsh
echo 'Hello, $name'
```

Output:

```text
Hello, $name
```

Some variables already exist:

```zsh
echo "$HOME"
echo "$PATH"
```

`HOME` is your home directory. `PATH` lists directories where the shell searches for programs.

To make a variable available to programs you launch, export it:

```zsh
export MY_SETTING="enabled"
```

A Python program launched from that shell can then read it through `os.environ`.

## 6. Match filenames with wildcards

```zsh
ls *.txt
```

Zsh expands `*.txt` into matching filenames before running `ls`.

Common patterns:

| Pattern | Matches |
|---|---|
| `*.txt` | Names ending in `.txt` |
| `notes*` | Names starting with `notes` |
| `file?.txt` | Names such as `file1.txt` or `fileA.txt` |

By default, Zsh reports `no matches found` if a wildcard matches nothing.

Quoting prevents expansion:

```zsh
echo "*.txt"
```

That prints the literal text `*.txt`.

## 7. Redirect output and connect commands

Create a file containing a few lines:

```zsh
printf 'pear\napple\nbanana\n' > fruit.txt
```

`printf` prints formatted text. Here, `\n` means a newline, and `>` sends the output into a file.

Read it:

```zsh
cat fruit.txt
```

Sort its contents:

```zsh
sort fruit.txt
```

Save the sorted result:

```zsh
sort fruit.txt > sorted-fruit.txt
```

- `>` creates a file or overwrites its existing contents.
- `>>` appends to a file.

A **pipe**, written `|`, sends one command's output into another command's input:

```zsh
cat fruit.txt | sort
```

For this example, `sort fruit.txt` is simpler. Pipes become useful when you combine several operations:

```zsh
cat fruit.txt | sort | wc -l
```

`wc -l` counts lines, so this prints `3`.

## Try it yourself

Inside your practice directory:

1. Create a file called `shopping list.txt`.
2. List all `.txt` files.
3. Copy `fruit.txt` to `fruit-backup.txt`.
4. Append `orange` as another line in `fruit.txt`.
5. Count the lines in `fruit.txt`.

The key idea is that **Zsh interprets your command first**. It handles quotes, variables, wildcards, pipes, and redirection, then runs the programs with the resulting arguments.
