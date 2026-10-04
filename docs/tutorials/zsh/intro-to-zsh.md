# Intro to Zsh

A hands-on book that progresses from using the terminal to writing Zsh scripts and customizing the shell itself.

Start with [Chapter 1: Basic Zsh](ch1.md). It assumes no shell experience. Later chapters build on its commands and practice directory.

## Book layout

This file is the book's entry point. Chapters live beside it as `ch1.md`, `ch2.md`, and so on.

Chapter 1 is available now. Chapters 2 through 15 below are planned.

## Part I: Basic

### 1. Basic Zsh

Available in [ch1.md](ch1.md).

- Navigate directories and create, copy, move, and remove files.
- Understand commands, arguments, quoting, variables, and exported environment variables.
- Use completion, history, wildcards, redirection, and simple pipelines.
- Practice in a dedicated directory.

### 2. Working efficiently at the prompt

Planned file: `ch2.md`.

- Edit command lines, use history search, and recall previous arguments.
- Explore completion menus and directory stacks.
- Find commands with `type`, `command -v`, and Zsh's `whence`.
- Read help and manuals; distinguish builtins, external programs, aliases, and functions.
- Exercise: navigate a sample project and build a repeatable command-line workflow.

### 3. Processes, streams, and exit status

Planned file: `ch3.md`.

- Follow standard input, standard output, and standard error through commands.
- Redirect streams, use `tee`, and understand redirection order.
- Read exit status and combine commands with `&&` and `||`.
- Run background jobs, suspend and resume them, and send signals.
- Exercise: run a background task and capture its output and errors separately.

### 4. Configuring your shell

Planned file: `ch4.md`.

- Understand interactive and login shells and the startup-file loading order.
- Choose what belongs in `.zshenv`, `.zprofile`, and `.zshrc`; introduce `ZDOTDIR`.
- Manage `PATH`, aliases, history persistence, and shell options.
- Introduce `bindkey` and select an Emacs or Vi editing mode.
- Exercise: build a small, understandable configuration and try it in a fresh shell.

## Part II: Intermediate

### 5. Expansion, quoting, and arrays

Planned file: `ch5.md`.

- Trace parameter, command, arithmetic, and filename expansion.
- Use defaults, substitutions, and string operations in parameter expansion.
- Work with indexed arrays, associative arrays, and Zsh's tied `path` and `PATH` parameters.
- Explain native Zsh word splitting, array expansion, and indexing differences from Bash.
- Exercise: build a command's argument list as an array without losing spaces in filenames.

### 6. Finding files with Zsh globbing

Planned file: `ch6.md`.

- Use recursive patterns, exclusions, and extended globbing.
- Select files by type, age, size, and other glob qualifiers.
- Handle hidden files and unmatched patterns explicitly.
- Preview matches before applying a batch operation.
- Exercise: select and copy a set of files using a precisely defined pattern.

### 7. Writing your first scripts

Planned file: `ch7.md`.

- Create executable scripts with a Zsh shebang; distinguish execution from sourcing.
- Read positional arguments and use conditions, loops, `case`, and arithmetic.
- Understand tests, exit codes, and basic validation.
- Label Zsh-specific syntax and identify when a script needs a portable shell instead.
- Exercise: write a script that summarizes files in a supplied directory.

### 8. Functions and command-line interfaces

Planned file: `ch8.md`.

- Define functions, use local variables, and return meaningful statuses.
- Parse options with `getopts`; introduce `zparseopts` for richer Zsh-specific interfaces.
- Provide help text and validate arguments.
- Organize reusable functions with `fpath` and `autoload`.
- Exercise: turn the previous script into a reusable command with options and a help message.

### 9. Text processing and reliable file workflows

Planned file: `ch9.md`.

- Combine `grep`, `cut`, `sort`, `uniq`, `awk`, and other text-processing tools.
- Introduce command substitution and process substitution.
- Process filenames with arrays or null-delimited streams rather than parsing `ls` output.
- Account for spaces, newlines, and leading hyphens in filenames.
- Exercise: generate a report from sample logs and a directory of awkwardly named files.

## Part III: Advanced

### 10. Execution environments and failure handling

Planned file: `ch10.md`.

- Distinguish subshells, grouped commands, sourced files, and process replacement with `exec`.
- Control function behavior with `emulate -L zsh` and localized shell options.
- Inspect pipeline statuses with `pipestatus` and use `PIPE_FAIL` deliberately.
- Handle errors explicitly; explain the limits of `ERR_EXIT`.
- Use traps, temporary directories, and Zsh's `always` blocks for cleanup.
- Exercise: make a multi-step script clean up correctly when a command fails or execution is interrupted.

### 11. Building completion functions

Planned file: `ch11.md`.

- Initialize the completion system with `compinit` and understand `fpath`.
- Configure matching, grouping, and presentation with `zstyle`.
- Introduce completion contexts, `compdef`, `_arguments`, and `_describe`.
- Complete options and context-dependent values for a custom command.
- Exercise: add completion for the command developed in Chapter 8.

### 12. Customizing the Zsh line editor

Planned file: `ch12.md`.

- Explore ZLE keymaps and inspect existing bindings.
- Write widgets with `zle -N` and manipulate `BUFFER`, `LBUFFER`, `RBUFFER`, and `CURSOR`.
- Integrate a selection tool without breaking quoting or command-line state.
- Understand redisplay and widget composition.
- Exercise: write a widget that inserts a selected project directory as a quoted argument.

### 13. Prompts, hooks, and interactive automation

Planned file: `ch13.md`.

- Build prompts with prompt escapes, conditional segments, and `RPROMPT`.
- Explain prompt substitution and the cost of running commands on every redraw.
- Register `precmd`, `preexec`, and `chpwd` hooks with `add-zsh-hook`.
- Introduce `vcs_info` for version-control information.
- Exercise: build a prompt with exit status and Git information, plus a directory-change hook.

### 14. Debugging, testing, and performance

Planned file: `ch14.md`.

- Check syntax with `zsh -n` and inspect execution with tracing.
- Reproduce configuration problems in a clean `zsh -f` session.
- Write behavioral checks for success, failure, and unusual inputs.
- Profile startup and functions with `zsh/zprof`; introduce `zmodload` and module discovery.
- Evaluate plugin costs and keep startup behavior predictable.
- Exercise: diagnose a broken configuration and measure an improvement to slow startup code.

### 15. Capstone: a project workspace command

Planned file: `ch15.md`.

- Build an autoloaded command that registers, lists, and selects project directories.
- Add argument validation, completion, and a line-editor widget.
- Make persistent state updates reliable and test failure cases and unusual paths.
- Measure startup impact and document installation, usage, and Zsh requirements.
- Deliver a working tool that combines the book's scripting and interactive customization techniques.

## Chapter format

Each new chapter will include:

- Learning goals and prerequisites.
- Short explanations paired with runnable examples and expected results.
- Explicit notes when behavior depends on shell options or differs from Bash.
- Exercises using disposable practice files, with worked solutions after the exercises.
- A summary and links to the previous and next chapters.

Examples will distinguish Zsh features from external Unix tools and identify platform-specific commands where needed.
