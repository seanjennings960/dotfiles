# Chapter 3: Arguments

[Book contents](intro-to-zsh.md) | [Previous: Context](ch2.md) | [Next: Execution](ch4.md) | [Companion](companion/README.md)

Start at the repository root. Run `zsh -f`, then keep this shell for the examples:

```zsh
tutorial=$PWD/docs/tutorials/zsh
scratch=$(mktemp -d)
cd "$scratch"
```

## Inspect the words

A program receives an ordered list of strings called `argv`. By convention, `argv[0]` is its invocation name. The remaining entries are arguments. Spaces separate words in shell source, but an argument can contain spaces or newlines. NUL cannot occur in an external program's argument. Grouping quotes disappear before the command runs.

This function counts its arguments and prints each as escaped Zsh text:

```zsh
show_args() {
  emulate -L zsh
  local arg
  printf 'count=%d\n' "$#"
  for arg in "$@"; do
    printf '%q\n' "$arg"
  done
}
label='two words'
show_args $label "$label" '$label' ''
```

Output:

```text
count=4
two\ words
two\ words
\$label
''
```

The escapes describe argument boundaries; they are not part of the values. Single quotes preserve literal text. Double quotes allow expansion while preserving one scalar argument, including an empty string. A backslash quotes the next character, so `two\ words` also supplies one argument.

Native Zsh leaves unquoted scalar expansions unsplit with `SH_WORD_SPLIT` off and does not glob their contents with `GLOB_SUBST` off. Bash normally splits unquoted scalar expansions using `IFS`, then expands wildcards in the resulting words. Quote scalars anyway: a standalone unquoted empty scalar disappears in Zsh too. `emulate -L zsh` gives reusable functions native defaults and restores the caller's options on return.

## Expansion changes values and counts

```zsh
unset topic
show_args "${topic:-untitled}" "$((2 + 3))" "$(printf 'a\nb\n\n')"
```

Output:

```text
count=3
untitled
5
a$'\n'b
```

`${topic:-untitled}` substitutes a default when `topic` is unset or empty; it does not assign it. Arithmetic expansion produces `5`. Command substitution runs the command, captures its standard output, and removes **all trailing newlines**, even inside double quotes. The internal newline survives. `$'\n'` represents a newline in Zsh source.

Unquoted command substitution does undergo word splitting in native Zsh. `show_args $(printf 'a b\n')` receives two arguments. Quoting preserves boundaries but cannot restore stripped newlines. Do not capture arbitrary filenames through command substitution.

## Select filenames without losing boundaries

An indexed array stores separate strings. Native Zsh indexes it starting at one; `"${names[@]}"` expands to one argument per element.

```zsh
names=('draft one.txt' $'draft\ntwo.txt' '-todo.txt')
touch -- "${names[@]}" .hidden.txt
files=( ./*.txt(N.) )
show_args "${files[@]}"
```

Expect `count=3`, with the newline escaped on one output line. `names[1]` holds `draft one.txt`. Arrays also preserve empty elements.

The shell expands a glob before calling the command. `*` matches any sequence within a path component; `?` matches one character. Neither crosses `/`. Quoting `'*.txt'` makes it literal. A leading dot requires an explicit dot or the `D` qualifier. By default, an unmatched pattern raises `no matches found` and prevents execution.

Zsh's trailing glob qualifiers make selection local to one pattern. In `./*.txt(N.)`, `N` removes an unmatched pattern instead of raising an error, and `.` selects regular files. Use `./*.txt(ND.)` to include hidden files, giving four here. `./**/*.txt(ND.)` also searches subdirectories without following symlink directories.

`--` ends option parsing in commands that support it. The `./` prefix also keeps filenames from looking like options. Neither spaces nor newlines require special handling once each pathname occupies one array element.

For a stream of filenames, use NUL delimiters. Unix filenames cannot contain NUL:

```zsh
find . -type f -print0 |
  while IFS= read -r -d '' file; do
    show_args "$file"
  done
```

This prints four separate `count=1` records. `IFS=` prevents trimming, `-r` preserves backslashes, and `-d ''` reads through NUL. Do not parse `ls` output or split filename lists on newlines.

## Exercise: forward an exact workspace call

Write `wsadd [-n] [--] NAME DIRECTORY`, a wrapper around the shared [workspace helper](examples/workspace.zsh). With `-n`, inspect the arguments that `ws` would receive. Otherwise call `ws add`. Reject unknown options and missing or extra operands with status 2. Allow `--` before a name beginning with `-`.

`$#` counts positional arguments; `$1` and `$2` access them. Forward them with `"$@"`, which preserves each argument, including empty ones. `"$*"` joins them into one string.

### Worked solution

```zsh
wsadd() {
  emulate -L zsh
  local opt OPTARG
  local -i OPTIND=1 dry=0
  local usage='usage: wsadd [-n] [--] NAME DIRECTORY'
  while getopts ':n' opt; do
    case $opt in
      n) dry=1 ;;
      *) print -u2 -- "$usage"; return 2 ;;
    esac
  done
  shift $((OPTIND - 1))
  if (( $# != 2 )); then
    print -u2 -- "$usage"
    return 2
  fi
  if (( dry )); then
    show_args add "$@"
  else
    ws add "$@"
  fi
}
```

`getopts` consumes short options before operands. Its leading colon requests explicit error handling. Local `OPTIND` starts each call afresh; `shift` removes consumed options, including `--`. After shifting, `$1` is `NAME` and `$2` is `DIRECTORY`.

Test with a disposable registry and a directory containing both spaces and a newline:

```zsh
export WS_HOME=$scratch/registry
source "$tutorial/examples/workspace.zsh"
project=$scratch/$'project\nwith spaces'
mkdir -- "$project"
wsadd -n -- -demo "$project"
wsadd -- -demo "$project"
ws go -demo
[[ $PWD -ef "$project" ]] && print -r -- 'same directory'
ws list
```

The dry run prints `count=3`: `add`, `-demo`, and one escaped pathname. Expect `same directory` after selection; `-ef` compares filesystem identity even through symlinks. `wsadd -x` and `wsadd demo` print usage and return 2. `ws` validates names and directories; its listing is human-readable, not a filename protocol.

Return to the repository and remove the practice files:

```zsh
cd "$tutorial/../../.." && rm -r -- "$scratch"
```
