# Push to talk (macOS)

```sh
nix run .#push-to-talk -- --check
nix run .#push-to-talk | tee transcript.txt
```

Hold **Caps Lock** to record the default microphone; release it to transcribe.
One utterance per line goes to stdout, flushed immediately. Status and errors go
to stderr. By default nothing is pasted or typed into another app. Audio is not
uploaded by the packaged transcriber. Ctrl-C stops
the listener, discards an unreleased recording, and finishes pending transcripts.
Recordings are private temporary files, deleted after transcription or shutdown.
Each recording and transcription is limited to 120 seconds.

## Select a microphone

Discover available inputs, then select one by its UID or exact name:

```sh
nix run .#push-to-talk -- --list-microphones
nix run .#push-to-talk -- --microphone 'MacBook Air Microphone'
# Or use the stable UID printed in the first column:
nix run .#push-to-talk -- --microphone 'BuiltInMicrophoneDevice'
```

Discovery does not record or request microphone/keyboard permissions. Without
`--microphone`, the macOS default input is used. Selection affects only this
process, not the system default. If names are duplicated, use the UID. A missing
selected input is rejected instead of silently using another microphone.

## Paste into the focused input

```sh
nix run .#push-to-talk -- --paste --microphone 'Scarlett 2i2 USB'
```

`--paste` also copies each completed transcript to the clipboard and sends
**Cmd-V** to whichever app/input has focus **when transcription finishes**.
Focus the intended input before releasing the hotkey and leave it focused until
the text appears. No Enter/Return is sent and stdout is still available. Apps
that do not accept normal Cmd-V pastes may not support this feature.

This replaces your clipboard contents; it does not restore the old clipboard.
Enable **Ghostty** (or your terminal) in **System Settings > Privacy & Security >
Accessibility**, then quit and reopen it. `--paste` requests this extra permission
on startup and fails before recording if it has not been granted. Check without
prompting using `nix run .#push-to-talk -- --paste --check`.

## Permissions and hotkeys

On first use, grant your terminal **Microphone** and **Input Monitoring** access
in **System Settings > Privacy & Security**, then quit and reopen the terminal.
`--check` only inspects permissions; it does not request them. Accessibility
permission is needed only with `--paste`. No root privileges, background service,
or login item is needed.

The hotkey observes physical HID press/release events globally, even when another
app has focus. It does not grab the keyboard or change macOS key mappings.
Consequently Caps Lock retains its normal capitalization effect. To dedicate it
to voice, set **Keyboard > Keyboard Shortcuts > Modifier Keys > Caps Lock > No
Action**, or select another single key:

```sh
nix run .#push-to-talk -- --key right-option
nix run .#push-to-talk -- --key f18
```

Only one selected key is monitored. Repeated presses are ignored while held;
disconnecting a held keyboard releases the recording. Transcription is queued
in utterance order without blocking subsequent recording.

## Transcription and microphone packages

`pkgs/transcribe.nix` packages whisper.cpp and a fixed-hash English `base.en`
model (~148 MB, fetched by Nix at build time). Once built, transcription works
offline, with Metal acceleration on Apple Silicon. Override the model/language
with `WHISPER_MODEL=/path/to/ggml-model.bin` and `WHISPER_LANGUAGE=auto` when using
a multilingual model. Test an existing WAV without device permissions:

```sh
nix run .#transcribe -- recording.wav
```

Use a different installed transcriber with `--transcriber 'my-transcriber --plain'`.
The WAV filename is appended as one argument; no shell is evaluated. The command
must write only transcript text to stdout, diagnostics to stderr, and exit nonzero
on failure. A failed utterance is reported and removed, not retried.

`modules/devices/microphone.nix` packages a reusable native Core Audio recorder:

```sh
nix run .#microphone -- recording.wav
# Ctrl-C finalizes 16 kHz, mono, signed 16-bit PCM WAV.
nix run .#microphone -- --list
nix run .#microphone -- --device 'MacBook Air Microphone' recording.wav
```

It emits `READY` on stdout only once capture starts; SIGINT/SIGTERM stops and
finalizes the file. `--authorize` requests permission without recording.

## Testing on the MacBook Air

```sh
nix build .#push-to-talk   # Also runs process-level tests without device access.
nix flake check --no-build
nix run .#push-to-talk -- --check
```

For a live check, start the pipe above, focus another app, hold Caps Lock, speak,
and release. Confirm one line appears only on release, repeat while transcription
is running, and verify Ctrl-C turns off the microphone. Physical keyboard and
live microphone tests require an interactive logged-in session and TCC approval;
the automated tests do not bypass macOS permissions or record ambient audio.

Verified on the host M3 MacBook Air: native Nix build, process-level tests,
permission checks, and packaged Whisper transcription of generated speech.
Focused-input paste is covered by process-level tests; end-to-end GUI delivery
still requires Accessibility approval and an interactive check.
