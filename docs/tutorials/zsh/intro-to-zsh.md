# Intro to Zsh

Open a terminal and type:

```sh
pwd
```

You have asked the computer which directory you are in. It prints a path and waits for your next command.

That is where this book starts. We will move between directories, make a few files, and learn how to give commands the information they need. Then we will put commands together and save work we want to repeat.

Zsh is the shell we will use. A shell reads commands and runs them. It also handles things such as quotes and wildcards before a program sees its arguments. You do not need to know those rules yet. We will meet them through examples.

## Why this book is here

The [repository's roadmap](../../project.md#goal) says:

> I want to explore, understand, and edit agent-generated code, rather than let
> coding speed outstrip my understanding of it.

An agent may suggest a command to run your tests or find some files. Knowing the shell lets you read that command and check what it did. When it does something useful, you can keep it in a script and run it again yourself.

This repo also contains a personal [`zshrc`](../../../zshrc). By the end of the book, settings in files like this should be things you can explain and change. Completion, history, and small functions become more useful when you understand how they work.

The roadmap starts with Bash and evaluates Zsh. Your agent or test system may use a different shell. We will point out where that matters, rather than assume every command runs in your usual terminal.

## How to read the book

Start with [Chapter 1: Basic Zsh](ch1.md). Type the examples in order and compare the results with the text. Most examples work on files you create for practice. Each chapter ends with an exercise and a worked solution.

| Chapter | What you will do |
| --- | --- |
| [1. Basic Zsh](ch1.md) | Move around, create files, and run your first commands. |
| [2. Where commands run](ch2.md) | Find out why the same command can behave differently in another shell or directory. |
| [3. Giving commands arguments](ch3.md) | Pass names and values without accidentally changing them. |
| [4. Putting commands together](ch4.md) | Write a script and decide what it should do when a step fails. |
| [5. Working at the prompt](ch5.md) | Recall commands, complete names, and make the prompt show useful information. |

Chapters 2 through 5 begin at the repository root, the directory containing `README.md` and `zshrc`. Each starts a new practice shell and makes a temporary directory. The instructions at the end remove that directory and return to your previous shell.

We will use a small [workspace function](examples/README.md) that remembers project directories by name. First you will use it. Later you will have the tools to read its implementation and add completion for it.

## Four questions to come back to

The book keeps returning to four questions. These are names for things you will observe, not definitions to memorize before starting.

| Idea | Question |
| --- | --- |
| Context | Where is this command running, and which settings does it use? |
| Arguments | What information does the command receive? |
| Execution | How do commands pass results to each other, and what happens if one fails? |
| Interaction | How can the shell help you enter commands and see what happened? |

When a command surprises you, use these questions to decide what to inspect next.

## Terminal companion

You can also read the book in a [small terminal application](companion/README.md). From the repository root, run:

```sh
python3 docs/tutorials/zsh/companion/tui.py
```

Press `1` through `5` to choose a chapter, Up or Down to scroll, and `q` to quit. Press `d` to run a short demonstration and see its commands beside the results. The demonstrations use temporary directories.

The application needs Python 3.9+ with its standard-library curses module. Its demonstrations also need Zsh. You can read the Markdown files and work through the book without the application.
