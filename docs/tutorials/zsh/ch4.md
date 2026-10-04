# Chapter 4: Putting commands together

[Book contents](intro-to-zsh.md) | [Previous: Giving commands arguments](ch3.md) | [Next: Working at the prompt](ch5.md) | [Companion](companion/README.md)

In Chapter 1, `sort fruit.txt | wc -l` connected two programs. One produced lines; the other counted them.

We will build on that idea. First we will clean up a list of names. Then we will save the operation as a script and make sure a failed run leaves the previous result intact.

Start at the repository root and launch a clean Zsh session:

```sh
zsh -f
```

Keep the following examples in this shell:

```zsh
repo=$PWD
tutorial=$repo/docs/tutorials/zsh
lab=$(mktemp -d)
cd "$lab"
```

## 1. Give one command's output to another

Make a short list:

```zsh
printf 'Beta\nalpha\nBeta\n' > input
cat input
```

It contains `Beta`, `alpha`, and another `Beta`. We want lowercase names with duplicates removed.

`tr` replaces characters. This command changes uppercase letters to lowercase:

```zsh
tr '[:upper:]' '[:lower:]' < input
```

`< input` tells the shell to open the file as the command's standard input. Expect `beta`, `alpha`, then `beta`.

Pass that result to `sort -u`:

```zsh
tr '[:upper:]' '[:lower:]' < input | LC_ALL=C sort -u
```

Output:

```text
alpha
beta
```

The `-u` option removes duplicate lines. `LC_ALL=C` selects a fixed byte ordering rather than an ordering based on the user's language settings. The input file is unchanged; we have only printed a result.

## 2. Keep results and errors separate

Programs have three usual streams:

| Stream | Number | Usual purpose |
| --- | --- | --- |
| Standard input | `0` | Data to read. |
| Standard output | `1` | Results to pass on or save. |
| Standard error | `2` | Diagnostics to show separately. |

The numbers are file descriptors. A pipe connects standard output, but leaves standard error separate.

Use a small function to see the difference:

```zsh
emit() {
  print out
  print -u2 err
}
emit > output
cat output
```

The call to `emit` shows `err` on the terminal. `cat output` shows `out`. `print -u2` sent the diagnostic to stream 2, so `>` did not capture it.

To save both streams together:

```zsh
emit > both 2>&1
cat both
```

The file contains `out` then `err`. `2>&1` gives standard error the same destination that standard output has at that point.

The order matters. Try reversing the two redirections:

```zsh
emit 2>&1 > output
```

Now `err` appears on the terminal again. First, stream 2 copied stream 1's terminal destination. Then stream 1 moved to the file. Stream 2 kept the destination it had already copied.

## 3. Ask whether a command succeeded

Output tells you what a program printed. Its exit status tells you whether it succeeded. Zero means success; a nonzero status means failure.

`true` always succeeds and `false` always fails, which makes them useful for experiments:

```zsh
false
echo "$?"
true
echo "$?"
```

These print `1`, then `0`. `$?` holds the status of the most recent command.

What should a pipe report when one command fails and the next succeeds?

```zsh
false | true
echo "$?"
```

By default, this prints `0`. A pipeline reports its last command's status. To inspect the individual commands, Zsh provides the `pipestatus` array:

```zsh
(
  false | true
  result=( "$?" "${pipestatus[@]}" )
  print -r -- "${result[@]}"
  setopt PIPE_FAIL
  false | true
  result=( "$?" "${pipestatus[@]}" )
  print -r -- "${result[@]}"
)
```

Expect `0 1 0`, then `1 1 0`. Each line shows the overall status followed by the two command statuses. `PIPE_FAIL` makes the overall status the rightmost failure, or zero if all commands succeed.

We save both values in one assignment because even printing a status replaces it with a new status. The parentheses keep the option change in a subshell.

## 4. Choose what happens next

An `if` uses a command's status to choose which commands to run:

```zsh
if [[ -f input ]]; then
  echo 'input exists'
else
  echo 'input is missing'
fi
```

`[[ -f input ]]` succeeds when `input` is a regular file. Here the output is `input exists`. `then` begins the successful branch, `else` begins the other branch, and `fi` ends the choice.

For short cases, `a && b` runs `b` after `a` succeeds, while `a || b` runs it after `a` fails. These decisions use exit status, not the text printed by `a`.

Now give our earlier pipeline a name:

```zsh
normalize() {
  emulate -L zsh
  setopt PIPE_FAIL
  tr '[:upper:]' '[:lower:]' | LC_ALL=C sort -u
}
normalize < input
```

It still prints `alpha` and `beta`. A function can read input and produce output just like an external command. Its last command supplies its status unless it uses `return` to choose another one.

## 5. Replace a saved result only after success

We could write straight to a report, but `>` empties an existing file before the command runs. See this happen with `false`:

```zsh
printf 'previous report\n' > report
false > report
wc -c < report
```

`wc -c` counts bytes. It prints `0`. The command failed, but the old contents are already gone.

Instead, we will write to a temporary file. Once the operation succeeds, we will rename that file to `report`. If it fails, we will remove the temporary file and keep the old report.

Save this script. The heredoc works the same way as the function file in Chapter 2:

```zsh
cat > publish-names.zsh <<'ZSH'
#!/usr/bin/env zsh
emulate zsh
setopt PIPE_FAIL

normalize() {
  local -a result
  tr '[:upper:]' '[:lower:]' | sort -u
  result=( "$?" "${pipestatus[@]}" )
  (( result[1] == 0 )) || print -u2 -- "filter stages: ${result[2,-1]}"
  return "${result[1]}"
}

if (( $# != 2 )); then
  print -u2 'usage: publish-names.zsh INPUT OUTPUT'
  exit 2
fi
input=$1
output=${2:a}
[[ ! -d $output ]] || { print -u2 'output is a directory'; exit 1; }
tmp=$(mktemp "${output}.XXXXXX") || exit 1
trap 'rm -f -- "$tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if LC_ALL=C normalize < "$input" > "$tmp"; then
  mv -f -- "$tmp" "$output" || exit 1
else
  exit 1
fi
ZSH
chmod +x publish-names.zsh
```

The first line chooses Zsh through `PATH`. The argument check requires an input filename and an output filename. `exit` ends the script, while `return` leaves only a function.

Inside `normalize`, we added a saved copy of the pipeline statuses. If the pipeline fails, the function prints its individual statuses and returns the failure. `${result[2,-1]}` selects the array elements after the overall status, through the last element.

The remaining steps implement the plan:

1. `${2:a}` makes the output path absolute. The script rejects a directory as its output file.
2. `mktemp` creates a temporary file beside that output. The two files are on the same filesystem, which lets a rename replace the whole result at once.
3. The `if` checks `normalize`. Only success reaches `mv`, which publishes the new report.
4. The `EXIT` trap removes the temporary file when the script ends. A trap names commands to run when an event occurs.

Try a successful run and then one with a missing input:

```zsh
for file in input absent; do
  ./publish-names.zsh "$file" report
  print -r -- "status=$?"
done
cat report
```

The `for` loop runs once with `file=input`, then again with `file=absent`. Expect `status=0`, a missing-file diagnostic, and `status=1`. The final `cat` still prints `alpha` and `beta`.

The script uses status `2` for wrong arguments, `1` for failed file operations, and `0` for successful publication. `emulate zsh` selects normal Zsh options while preserving tracing, which we will use below.

## 6. Make failure handling explicit

You may encounter `set -e`, also called `ERR_EXIT`. It asks the shell to exit on some failures. It has exceptions, so it does not replace the checks we just wrote:

```zsh
zsh -fc 'setopt ERR_EXIT; step() { false; print continued; }; if step; then print accepted; fi'
```

This prints `continued` and `accepted`, even though `false` failed. Testing a function with `if` suppresses automatic exit inside it. Our report script checks the operation's result explicitly before replacing the file.

A function can also need cleanup before returning. Zsh's `always` block does that:

```zsh
leave() {
  { return 7; } always { print cleaned; }
}
leave
print -r -- "$?"
```

Expect `cleaned`, then `7`. The function returned a failure status, but its cleanup still ran. The workspace helper uses this form to close files and remove temporary records.

## 7. Start and stop a background job

Put `&` after a command to run it in the background:

```zsh
sleep 60 &
pid=$!
jobs
```

The shell gives you another prompt while `sleep` runs. `$!` is the new process's identifier, or PID. `jobs` lists the shell's jobs.

Stop it and collect its status:

```zsh
kill -TERM "$pid"
wait "$pid"
print -r -- "$?"
```

Expect `143`, the shell convention for a process terminated by the TERM signal. `wait` waits for the process and returns its status.

For a foreground job, Ctrl+Z suspends it. `bg` resumes it in the background, and `fg` brings it back. Ctrl+C sends INT to the foreground process group.

The report script traps INT and TERM and exits with statuses `130` and `143`. Its exit cleanup then runs. KILL and a machine crash cannot run cleanup. Sending a signal to one script PID also does not necessarily signal all its children.

## 8. Inspect a script as it runs

First check whether Zsh can parse the script:

```zsh
zsh -n publish-names.zsh
```

No output means the syntax check passed. This does not run the script, so it cannot tell whether its input file exists.

Now run it with tracing:

```zsh
PS4='+%N:%i> ' zsh -x publish-names.zsh input report
```

Zsh prints each expanded command to standard error before executing it. `PS4` controls the trace prefix; this one includes the source name and line number. You can compare the values in the trace with the values you expected.

## 9. Give a command two generated inputs

A pipe gives a command one input stream. Some commands take filenames for more than one input. `diff`, for example, compares two files.

Make the same list in another order:

```zsh
printf 'alpha\nBeta\nBeta\n' > reordered
diff <(LC_ALL=C sort input) <(LC_ALL=C sort reordered)
echo "$?"
```

`diff` prints nothing and its status is `0`. The sorted inputs match. Each `<(...)` supplies a filename connected to a command's output. This is process substitution.

Those commands are not stages in `diff`'s pipeline, so their failures do not reliably determine its status. If a saved report depends on them succeeding, write their outputs to files and check each result first. The report script above uses a checked pipeline instead.

## Try it yourself

The [workspace helper](examples/workspace.zsh) also writes a temporary file and renames it after success. Each saved name identifies a file containing an absolute directory followed by NUL. Registering the same name again replaces that record.

Register a temporary project. Then try to replace its entry with a directory that does not exist. Check that you can still enter the original directory. Also check that selecting an unknown name leaves you where you were.

### Worked solution

```zsh
source "$tutorial/examples/workspace.zsh"
export WS_HOME="$lab/state"
mkdir "$lab/project one"
ws add demo "$lab/project one"
if ws add demo "$lab/missing"; then
  print 'unexpected success'
else
  print 'add rejected'
fi
ws go demo
[[ . -ef "$lab/project one" ]] && print 'old record kept'
before=$PWD
if ! ws go unknown; then
  [[ $PWD == "$before" ]] && print 'cwd preserved'
fi
```

Expect failure diagnostics plus `add rejected`, `old record kept`, and `cwd preserved`. `-ef` checks that two paths identify the same directory. `!` reverses a command's success or failure for the `if`, so that branch runs when selection fails.

This is the point of checking failure cases: we can say what should remain true after a command fails, and then observe whether it does.

Finish outside the practice directory:

```zsh
cd "$repo"
rm -r -- "$lab"
exit
```
