# Chapter 3: Giving commands arguments

[Book contents](intro-to-zsh.md) | [Previous: Where commands run](ch2.md) | [Next: Putting commands together](ch4.md) | [Companion](companion/README.md)

In Chapter 1, quotes let us use a file named `my notes.txt`. The command needed one filename, even though the name contained a space.

That is the question for this chapter: what, exactly, does a command receive?

Start at the repository root and open a practice shell:

```sh
zsh -f
```

Save the repository path and enter a temporary directory:

```zsh
repo=$PWD
tutorial=$repo/docs/tutorials/zsh
lab=$(mktemp -d)
cd "$lab"
```

## 1. Count the arguments

Make a directory whose name contains a space:

```zsh
mkdir "project one"
ls
```

You should see one directory named `project one`. The quotes kept its name together. `mkdir` received one argument, without the grouping quotes themselves.

Let's make a function that shows the arguments it receives:

```zsh
show_args() {
  emulate -L zsh
  local arg
  printf 'count=%d\n' "$#"
  for arg in "$@"; do
    printf '%q\n' "$arg"
  done
}
show_args apple banana
```

Output:

```text
count=2
apple
banana
```

`$#` is the number of arguments. `"$@"` is the list, with each argument kept separate. The `for` loop gives each argument to `arg` in turn and runs `printf` for it.

The `%q` format asks `printf` to show a value as quoted Zsh text. This lets us see where spaces and newlines belong. Try:

```zsh
show_args 'two words' three
```

Output:

```text
count=2
two\ words
three
```

The backslash is how `%q` displays the space. It was not part of the original value. You can also type `two\ words` to supply one argument.

Programs receive an argument list, often called `argv`. By convention its first entry, `argv[0]`, is the invocation name. A shell function's `$1` starts with the first argument after its name.

## 2. Keep a value together

Save a value and use it several ways:

```zsh
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

The first two arguments have the same value. Single quotes make the third argument the literal text `$label`. The fourth argument is an empty string, which `%q` shows as `''`.

Why did unquoted `$label` remain one argument? Native Zsh does not normally split an ordinary variable's value on spaces. Spaces between words you type and spaces inside a stored value are different things.

Quotes still matter. Compare an empty value with and without them:

```zsh
empty=''
show_args "$empty"
show_args $empty
```

The first call prints `count=1` and `''`. The second prints only `count=0`. The unquoted empty value disappeared.

Bash normally splits an unquoted variable's value into words and then looks for wildcards in those words. Native Zsh leaves `SH_WORD_SPLIT` and `GLOB_SUBST` off. Quoting values keeps your intention clear across these differences. The `emulate -L zsh` in our helper also gives its body known Zsh option settings.

## 3. Put a calculated value in an argument

Zsh can replace part of your command before running it. This is called expansion. We have already seen `$label`. Here is a value with a fallback:

```zsh
unset topic
show_args "${topic:-untitled}"
```

It prints `count=1` and `untitled`. `${topic:-untitled}` uses the fallback when `topic` is unset or empty. It does not assign that value to `topic`.

Arithmetic uses `$((...))`:

```zsh
echo "$((2 + 3))"
```

This prints `5`. Command substitution, written `$(...)`, uses another command's output:

```zsh
result=$(printf 'a\nb\n\n')
show_args "$result"
```

Output:

```text
count=1
a$'\n'b
```

The internal newline survived, but the newlines at the end disappeared. Command substitution captures standard output and removes all trailing newlines. Double quotes cannot bring them back. `$'\n'` is Zsh notation for a newline character.

Unquoted command substitution also splits its output into words, even in native Zsh:

```zsh
show_args $(printf 'a b\n')
```

This receives two arguments, `a` and `b`. Use quotes when you want the captured output to remain one value. For arbitrary filenames, use the array or stream methods below instead of command substitution.

## 4. Keep a list as a list

So far, our variables have held one value each. An array holds several separate values:

```zsh
names=('notes.txt' 'my notes.txt')
show_args "${names[@]}"
```

Expect `count=2`, followed by the two names. `"${names[@]}"` supplies one argument for each array element. It also preserves empty elements.

To select one element, use its index:

```zsh
echo "${names[1]}"
```

This prints `notes.txt`. Native Zsh starts these indices at one.

Now try filenames that require more care:

```zsh
names=('draft one.txt' $'draft\ntwo.txt' '-todo.txt')
touch -- "${names[@]}" .hidden.txt
```

The first name has a space, the second has a newline, and the third begins with `-`. `--` tells `touch` that options have ended. Without it, a leading hyphen could look like an option.

## 5. Make a list by matching files

Collect the visible text files in an array:

```zsh
files=( ./*.txt(N.) )
show_args "${files[@]}"
```

Expect `count=3`. The newline appears escaped, on the same output line as the rest of its filename.

We added `(N.)` to the pattern from Chapter 1. The characters inside those parentheses are Zsh glob qualifiers:

| Qualifier | What it changes |
| --- | --- |
| `N` | No matches gives an empty list instead of an error. |
| `.` | Keep regular files, excluding directories and symlinks. |
| `D` | Include hidden names beginning with a dot. |

Try including hidden files:

```zsh
files=( ./*.txt(ND.) )
show_args "${files[@]}"
```

Now the count is `4`, because `.hidden.txt` is included. Qualifiers apply to this pattern alone; they do not change how the next glob behaves.

The `./` prefix makes every result start with a dot rather than a hyphen. A filename such as `./-todo.txt` cannot be mistaken for an option. Use `--` too when the command supports it.

For subdirectories, `./**/*.txt(ND.)` searches recursively without following symlink directories. Ordinary `*` and `?` do not cross `/`. Inspect the array before using it in a batch operation.

## 6. Pass filenames through a pipe

Our newline-containing filename shows why "one filename per line" is unreliable. A filename could occupy two lines. NUL is a byte that cannot occur in a Unix filename or an external program's argument, so it can mark the end of each filename without ambiguity.

`find -print0` uses that separator:

```zsh
find . -type f -print0 |
  while IFS= read -r -d '' file; do
    show_args "$file"
  done
```

This prints four separate `count=1` records. The `while` loop repeats as long as `read` finds another record. `-d ''` selects the NUL delimiter. `-r` preserves backslashes, and `IFS=` prevents trimming the value.

The details all serve the same purpose: keep each filename intact. Arrays do that inside the shell. NUL-delimited records do it in a stream. Parsing the display produced by `ls` does neither.

## 7. Add an option to a small command

Load the [workspace helper](examples/workspace.zsh) with a temporary registry:

```zsh
export WS_HOME=$lab/registry
source "$tutorial/examples/workspace.zsh"
wsadd() { ws add "$@"; }
wsadd demo "$lab/project one"
```

`wsadd` passes its arguments to `ws add`. The `"$@"` preserves each argument, just as it did in `show_args`. `"$*"` would join them into one string, which is not what `ws add` expects.

Suppose we want `-n` to preview the call instead of registering it. With `wsadd -n demo DIRECTORY`, the function should consume `-n`, then pass only `demo` and `DIRECTORY` onward.

Zsh's `getopts` reads short options for us. Replace the small function with this version:

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

Read the function in the order it runs:

1. `getopts ':n' opt` looks for `-n` before the ordinary arguments. The leading colon lets us handle option errors ourselves.
2. The `while` loop keeps reading options. `case` selects a response to each one. For `n`, it sets `dry` to `1`; otherwise it prints usage and returns status `2`.
3. `OPTIND` records where option parsing stopped. `shift` removes the consumed words, including `--` if present.
4. `$#` must now be `2`. If so, the function either displays the proposed arguments or calls `ws`.

`local -i` declares integer variables. In `((...))`, an arithmetic expression is a test: a nonzero value is true. Local `OPTIND=1` starts parsing afresh each time we call the function.

## Try it yourself

Register a directory containing both spaces and a newline under the name `-demo`. First preview the call with `-n`, then run it and enter the saved directory. How will you tell the option parser that `-demo` is a name rather than another option?

### Worked solution

```zsh
project=$lab/$'project\nwith spaces'
mkdir -- "$project"
wsadd -n -- -demo "$project"
wsadd -- -demo "$project"
ws go -demo
[[ $PWD -ef "$project" ]] && print -r -- 'same directory'
ws list
```

`--` ends option parsing. The preview prints `count=3`: `add`, `-demo`, and one pathname. After the real call, expect `same directory`. The `-ef` test checks that two paths identify the same directory, even if a symlink changes how the path is written.

Try `wsadd -x` and `wsadd demo`. Both print usage and return status `2`. The wrapper checks its options and argument count; `ws` checks whether the name and directory are valid.

The rule throughout this chapter has been the same: decide how many values the command should receive, then preserve those boundaries.

Return to the repository and remove the practice files:

```zsh
cd "$repo"
rm -r -- "$lab"
exit
```
