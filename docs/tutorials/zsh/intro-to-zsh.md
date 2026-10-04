# Intro to Zsh

This book starts with the [repository's goal](../../project.md#goal):

> I want to explore, understand, and edit agent-generated code, rather than let
> coding speed outstrip my understanding of it.

Shell fluency lets you investigate an agent's work. The same command text can invoke a different Python through `PATH`; a pipeline can report success after an earlier step failed. You need to understand the execution to judge the result.

In this repo's [terminal-first workspace](../../architecture.md#components), Zsh offers programmable completion and command-line editing. Understanding it lets you turn agent-generated operations into tested scripts and make deliberate choices about [`zshrc`](../../../zshrc). The aim is to retain authorship as agents generate more code.

The roadmap starts with Bash and evaluates Zsh. Agents and CI may use other shells or invoke programs directly; a noninteractive Zsh normally skips `.zshrc`. We will distinguish Zsh-specific behavior from portable ideas and interactive conveniences from script dependencies.

## Four concepts

| Concept | Question |
| --- | --- |
| Context | Where does a command run, and what state does it use? |
| Arguments | What exact words reach the command? |
| Execution | How does work run, connect, and finish? |
| Interaction | How do you enter commands and inspect shell state? |

Quoting and globbing belong together because both affect arguments. Scripts and functions package execution. Completion helps you construct a command; it does not change the command's requirements. Debugging and testing apply to all four concepts.

## Reading path

Start with [Chapter 1: Zsh in four concepts](ch1.md), a hands-on introduction that assumes no shell experience. The remaining chapters deepen the same concepts. Chapters 2 through 5 are planned.

| Planned chapter | Deeper study |
| --- | --- |
| 2. Context, `ch2.md` | Startup modes and files; command lookup and project `PATH` precedence; exported and local state; sourcing versus execution; subshells and localized options; autoloading. |
| 3. Arguments, `ch3.md` | Quoting and expansion; arrays and precise globbing; positional arguments and option parsing; preserving unusual filenames with arrays or null-delimited streams. |
| 4. Execution, `ch4.md` | Streams and process substitution; scripts, functions, and control flow; pipeline status and explicit error handling; jobs, signals, and cleanup; syntax checks and tracing. |
| 5. Interaction, `ch5.md` | History and keymaps; completion functions and line-editor widgets; prompts and hooks; profiling startup and interactive costs. |

Develop one workspace function across these chapters to register, list, and select project directories. Selection must change the calling shell's directory. Add validation and reliable state updates before completion and a line-editor widget. Test failures and unusual paths. Keep the tool small enough to understand in full.

Each chapter includes runnable examples and an exercise with a worked solution. Use disposable files and identify shell-option and platform differences. For an agent-proposed command, use the four questions to explain its behavior, then verify that explanation in the actual environment.
