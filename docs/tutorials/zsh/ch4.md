# Chapter 4: Execution

[Book contents](intro-to-zsh.md) | [Previous: Arguments](ch3.md) | [Next: Interaction](ch5.md) | [Companion](companion/README.md)

Execution asks how work runs, connects, and finishes. We will publish a normalized text report without replacing the previous report when a command fails.

Start at the repository root and launch a clean Zsh session:

```sh
zsh -f
```

Run the remaining examples in that shell. Capture the tutorial path before changing directory:

```zsh
tutorial=$PWD/docs/tutorials/zsh
lab=$(mktemp -d) && cd "$lab"
```

## Dataflow: connect streams

File descriptors `0`, `1`, and `2` are standard input, output, and error. A pipe connects stdout to the next command's stdin; stderr stays separate. Redirections happen left to right:

```zsh
emit() { print out; print -u2 err; }
emit > both 2>&1
emit 2>&1 > output
cat both
```

The second call prints `err` on the terminal. `cat both` prints `out` then `err`. `2>&1` copies stdout's destination at that moment. In the second call, stderr keeps the terminal destination after stdout moves to `output`. `>` truncates a file; `>>` appends.

Compose tools that each transform text:

```zsh
printf 'Beta\nalpha\nBeta\n' > input
tr '[:upper:]' '[:lower:]' < input | LC_ALL=C sort -u
LC_ALL=C comm -23 <(LC_ALL=C sort -u input) <(printf 'Beta\n')
```

`tr` lowercases letters; `sort -u` sorts and removes duplicates, producing `alpha` and `beta`. `comm -23` prints lines present only in its first sorted input, here `alpha`. `LC_ALL=C` gives predictable byte ordering.

Process substitution, `<(...)`, supplies a filename connected to a producer's output. Those producers are not stages in the caller's pipeline. Their failures do not reliably determine its status. When publication depends on them succeeding, save and check their outputs first. These examples process lines of text, not arbitrary filenames.

## Control: package an operation

Save this executable script in the practice directory:

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
for file in input absent; do
  ./publish-names.zsh "$file" report
  print -r -- "status=$?"
done
cat report
```

Expect `status=0`, a `no such file or directory: absent` diagnostic, then `status=1`. The report still contains `alpha` and `beta`. Wrong argument counts return `2`; I/O failures return `1`; successful publication returns `0`.

The shebang selects Zsh through `PATH`. `emulate zsh` resets compatibility options while preserving tracing. `normalize` packages the pipeline as a function; `return` leaves that function, while `exit` ends the script. `if` tests a status; `||` runs after failure, and `&&` runs after success. The `for` loop tries both inputs.

`${2:a}` makes the output path absolute. The temporary file sits beside the destination, so a same-filesystem rename publishes the whole report. Readers see the old or new file, never a half-written report.

## Failure lifecycle: inspect, stop, clean up

By default, a pipeline reports its last stage's status. Zsh's `pipestatus` array contains every stage's status. Capture both immediately, in one assignment:

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

Expect `0 1 0`, then `1 1 0`. `PIPE_FAIL` reports the rightmost failing stage, or zero when all succeed. Even a diagnostic command overwrites status information. The script checks the captured result before publishing.

`ERR_EXIT`, also spelled `set -e`, has exceptions:

```zsh
zsh -fc 'setopt ERR_EXIT; step() { false; print continued; }; if step; then print accepted; fi'
```

This prints `continued` and `accepted`. Testing a function with `if` suppresses automatic exit inside it. Explicit checks define correctness.

The script's `EXIT` trap removes its temporary file. INT and TERM request exits with statuses `130` and `143`. For function-scoped cleanup, an `always` block runs even across `return`:

```zsh
leave() {
  { return 7; } always { print cleaned; }
}
leave
print -r -- "$?"
```

Expect `cleaned` then `7`. Neither cleanup mechanism handles KILL or a machine crash. Signalling a script's PID does not necessarily signal its children.

```zsh
sleep 60 &
pid=$!
jobs
kill -TERM "$pid"
wait "$pid"
print -r -- "$?"
```

`&` starts a background job; `$!` saves its PID. Expect `143` after termination. Ctrl+Z stops a foreground job; `bg` resumes it in the background; `fg` brings it back. Terminal Ctrl+C sends INT to the foreground process group.

Check syntax without executing, then trace expanded commands to stderr:

```zsh
zsh -n publish-names.zsh
PS4='+%N:%i> ' zsh -x publish-names.zsh input report
```

Syntax checks cannot detect missing inputs. Traces include expanded argument values.

## Apply this to workspace state

The shared [workspace helper](examples/workspace.zsh) uses temporary-file-and-rename publication too. Nonempty names contain ASCII letters, digits, `_`, or `-`. Each record holds one NUL-terminated absolute directory. The last successful writer wins; cleanup removes only that writer's temporary file.

State lives under `${WS_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}/zsh-tutorial/workspaces}`. `ws list`, also bare `ws`, prints names and shell-quoted paths for people. `ws help` describes usage. Source the helper because `ws go` must change the calling shell's directory. Unknown names, malformed records, and missing target directories must fail without changing it.

## Try it yourself

Register a temporary project. Try replacing its entry with a missing directory, then prove the original entry still works. Also prove an unknown name preserves your current directory.

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

Expect failure diagnostics plus `add rejected`, `old record kept`, and `cwd preserved`. `-ef` compares directory identity, including through symlinks. `!` inverts status for the conditional. Finish by removing the practice directory:

```zsh
cd "$tutorial" && rm -r -- "$lab"
exit
```
