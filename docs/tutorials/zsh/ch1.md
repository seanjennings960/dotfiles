# Chapter 1: Basic Zsh

[Book contents](intro-to-zsh.md) | [Next: Where commands run](ch2.md) | [Companion](companion/README.md)

Zsh is a shell. It reads your commands, runs programs, and lets you combine them. It is the default shell on modern macOS and is included in this repo's development container.

Open a terminal. To make sure you are using Zsh, type:

```sh
zsh -f
```

The `-f` option skips the usual personal startup files. This gives us a predictable place to practice. Type the following commands one at a time and press Enter. If the prompt ends in `%` or `$`, do not type that symbol.

## 1. Find out where you are

Your shell always has a current directory. Ask which one it is:

```zsh
pwd
```

It prints a path, perhaps `/Users/sam` or `/home/sam`. Your path will be different.

Now list what is in that directory:

```zsh
ls
```

An option changes how a command behaves. Try:

```zsh
ls -l
```

The `-l` option adds details such as file size and modification time. `ls -a` also includes hidden names, which begin with a dot.

## 2. Make a place to practice

Go to your home directory:

```zsh
cd ~
```

`cd` changes directory, and `~` means your home directory. Make a new directory and enter it:

```zsh
mkdir zsh-practice
cd zsh-practice
pwd
```

Choose another name if `zsh-practice` already exists. `mkdir` creates the directory; `cd` enters it. The path printed by `pwd` should now end in `/zsh-practice`.

A path beginning with `/` is absolute. A path such as `notes.txt` is relative to the current directory.

Some useful movements are:

| Command | Where it goes |
| --- | --- |
| `cd ..` | The parent directory. |
| `cd ~` or `cd` | Your home directory. |
| `cd -` | Your previous directory. |

Stay in the practice directory for the following examples.

## 3. Make and move files

Create an empty file:

```zsh
touch notes.txt
ls
```

You should see `notes.txt`. Make a copy:

```zsh
cp notes.txt backup.txt
ls
```

Now there are two files. Rename the copy:

```zsh
mv backup.txt old-notes.txt
ls
```

`mv` can rename a file or move it to another directory. Remove the copy:

```zsh
rm old-notes.txt
```

`rm` deletes the file directly. It does not move it to the Trash. The original `notes.txt` is still there.

## 4. Give a command a filename

Look at this command:

```zsh
ls -l notes.txt
```

`ls` is the command. `-l` is an option. `notes.txt` tells it which file to describe. These extra words are called arguments.

Spaces normally separate arguments. What if a filename contains a space? Put quotes around it:

```zsh
touch "my notes.txt"
ls -l "my notes.txt"
```

The quotes tell Zsh to keep `my notes.txt` together. Without them, the command would receive `my` and `notes.txt` as separate arguments.

## 5. Save a value in a variable

A variable gives a value a name:

```zsh
name="Sam"
```

There are no spaces around `=`. Use `$name` to read the value:

```zsh
echo "$name"
```

`echo` prints its arguments, so this prints `Sam`. You can include the value in a longer message:

```zsh
echo "Hello, $name"
```

Output:

```text
Hello, Sam
```

Double quotes allow Zsh to replace `$name` with its value. Single quotes keep the text as you wrote it:

```zsh
echo 'Hello, $name'
```

This prints `Hello, $name`, including the dollar sign.

Some variables already exist:

```zsh
echo "$HOME"
```

`HOME` contains your home directory. We will use other variables in the next chapter.

## 6. Let Zsh find filenames

List the text files you have created:

```zsh
ls *.txt
```

Zsh replaces `*.txt` with the matching filenames before it runs `ls`. This kind of pattern is called a wildcard, or a glob.

| Pattern | What it matches |
| --- | --- |
| `*.txt` | Names ending in `.txt`. |
| `notes*` | Names beginning with `notes`. |
| `file?.txt` | Names such as `file1.txt` or `fileA.txt`. |

By default, these patterns skip hidden files. Zsh reports `no matches found` when a pattern finds nothing.

Quote a pattern when you want the text itself:

```zsh
echo "*.txt"
```

This prints `*.txt`. Quotes have stopped the filename matching.

## 7. Put output in a file

Print three lines:

```zsh
printf 'pear\napple\nbanana\n'
```

`printf` prints formatted text. Here, each `\n` starts a new line:

```text
pear
apple
banana
```

Run it again with `> fruit.txt` at the end:

```zsh
printf 'pear\napple\nbanana\n' > fruit.txt
```

This time the text goes into `fruit.txt` instead of appearing on the terminal. Read the file:

```zsh
cat fruit.txt
```

`cat` prints the file's contents. To see the lines in alphabetical order, run:

```zsh
sort fruit.txt
```

The output is `apple`, `banana`, then `pear`. The original file has not changed. Save that output in another file:

```zsh
sort fruit.txt > sorted-fruit.txt
```

`>` creates a file or overwrites its contents. Use `>>` to add output at the end instead:

```zsh
printf 'orange\n' >> fruit.txt
cat fruit.txt
```

The original file now has four lines.

## 8. Pass output to another command

`wc -l` counts lines:

```zsh
wc -l fruit.txt
```

It prints `4` and the filename. A pipe, written `|`, sends one command's output to another command:

```zsh
sort fruit.txt | wc -l
```

`sort` produces four sorted lines. `wc` receives those lines and counts them, so this prints `4`. It does not print a filename because it read the other command's output instead of opening a named file.

The shell has connected two programs. Neither program needs to know how the other one works.

## 9. Recall and edit commands

You do not need to retype everything. First select the keybindings used below:

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

`bindkey -e` chooses Zsh's Emacs-style editing keys for this session. It does not open an editor or change your saved configuration.

## Try it yourself

In the practice directory:

1. Copy `fruit.txt` to a file named `shopping list.txt`.
2. Add `grape` as another line in the copy.
3. Count the copy's lines. What number do you expect?

Try it before reading the solution.

### Worked solution

```zsh
cp fruit.txt "shopping list.txt"
printf 'grape\n' >> "shopping list.txt"
wc -l "shopping list.txt"
```

The result is `5`, followed by the filename. The quotes keep the filename together, and `>>` adds a line without replacing the earlier ones.

You have seen the main pattern of shell work: choose where to work, give a command its arguments, and decide where its output should go. Zsh handles the quotes, wildcards, and connections before the programs do their work.

Leave the practice shell with `exit`. Your practice files remain available to inspect. The next chapter uses a separate temporary directory.
