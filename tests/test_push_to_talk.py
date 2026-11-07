"""Exercise real child processes without requiring microphone/keyboard permissions."""

import importlib.util
import io
import os
from pathlib import Path
import subprocess
import sys
import time

import pytest


SOURCE = Path(os.environ.get(
    "PUSH_TO_TALK_SOURCE",
    Path(__file__).resolve().parents[1] / "modules/voice/push-to-talk/push_to_talk.py",
))
spec = importlib.util.spec_from_file_location("push_to_talk", SOURCE)
ptt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ptt)


@pytest.fixture
def make_controller(tmp_path):
    controllers = []

    def make(*, duration=0.3, microphone_source=None, transcriber_source=None, device=None, paste=False, paste_source=None):
        # Spaces in both executables and audio paths must survive without a shell.
        directory = tmp_path / f"utterances {len(controllers)}"
        directory.mkdir()
        microphone = directory / "fake microphone"
        microphone.write_text(f"#!{sys.executable}\n" + (microphone_source or f"""
import signal
import sys
import time
import wave

stopped = False
def stop(number, frame):
    global stopped
    stopped = True
signal.signal(signal.SIGINT, stop)
signal.signal(signal.SIGTERM, stop)
assert sys.argv[1:-1] == {(['--device', device] if device is not None else [])!r}
with wave.open(sys.argv[-1], 'wb') as audio:
    audio.setnchannels(1)
    audio.setsampwidth(2)
    audio.setframerate(16000)
    audio.writeframes(b'\\0\\0' * {int(duration * 16000)})
    print('READY', flush=True)
    while not stopped:
        time.sleep(0.01)
"""))
        microphone.chmod(0o755)
        transcriber = directory / "fake transcriber.py"
        transcriber.write_text(transcriber_source or """
import sys
import wave
assert sys.argv[1] == '--plain'
with wave.open(sys.argv[2], 'rb') as audio:
    assert (audio.getframerate(), audio.getnchannels(), audio.getsampwidth()) == (16000, 1, 2)
print('  hello from the microphone.  \\n  Another sentence. ')
""")
        stdout = io.StringIO()
        # Popen needs a real stderr file descriptor.
        stderr = (directory / "stderr").open("w+")
        paste_command = None
        if paste:
            helper = directory / "fake paste"
            helper.write_text(f"#!{sys.executable}\n" + (paste_source or f"""
from pathlib import Path
import sys
Path({str(directory / 'pasted.txt')!r}).write_text(sys.stdin.read())
"""))
            helper.chmod(0o755)
            paste_command = str(helper)
        controller = ptt.PushToTalk(
            directory, str(microphone), [sys.executable, str(transcriber), "--plain"],
            stdout=stdout, stderr=stderr, device=device, paste=paste_command,
        )
        controllers.append((controller, stderr))
        return controller, stdout, stderr

    yield make
    for controller, stderr in controllers:
        controller.close()
        stderr.close()


def errors(stderr):
    stderr.flush()
    stderr.seek(0)
    return stderr.read()


def test_hold_release_transcribes_and_removes_audio(make_controller):
    controller, stdout, stderr = make_controller()
    controller.release()  # Stray releases do nothing.
    controller.press()
    process, path = controller.recording
    assert process.poll() is None
    assert stdout.getvalue() == ""
    controller.press()  # Key repeat must not start another recorder.
    assert controller.recording == (process, path)
    controller.release()
    controller.release()
    controller.close()
    assert process.poll() == 0
    assert stdout.getvalue() == "hello from the microphone. Another sentence.\n"
    assert "recording" in errors(stderr)
    assert not path.exists()
    assert not (controller.directory / "pasted.txt").exists()


def test_paste_receives_plain_unicode_text_without_enter(make_controller):
    text = 'Café 🦊 says "hello"; $(this is not a shell command).'
    controller, stdout, _ = make_controller(
        paste=True, transcriber_source=f"print({text!r})\n",
    )
    controller.press()
    controller.release()
    controller.close()
    assert stdout.getvalue() == text + "\n"
    assert (controller.directory / "pasted.txt").read_text() == text


@pytest.mark.parametrize("source", ["print('   ')\n", "raise SystemExit(1)\n"])
def test_empty_or_failed_transcript_is_not_pasted(make_controller, source):
    controller, stdout, _ = make_controller(paste=True, transcriber_source=source)
    controller.press()
    controller.release()
    controller.close()
    assert stdout.getvalue() == ""
    assert not (controller.directory / "pasted.txt").exists()


def test_paste_failure_preserves_stdout_and_cleans_audio(make_controller):
    controller, stdout, stderr = make_controller(paste=True, paste_source="raise SystemExit(9)\n")
    controller.press()
    _, path = controller.recording
    controller.release()
    controller.close()
    assert stdout.getvalue() == "hello from the microphone. Another sentence.\n"
    assert "paste failed (transcript preserved on stdout)" in errors(stderr)
    assert not path.exists()


@pytest.mark.parametrize("paste", [False, True])
def test_accessibility_is_checked_only_when_paste_enabled(monkeypatch, paste):
    calls = []

    def run(command, **kwargs):
        calls.append(command)
        return subprocess.CompletedProcess(command, int(command[0] == "/test/paste"))

    monkeypatch.setattr(sys, "argv", ["push-to-talk", "--check", *(["--paste"] if paste else [])])
    monkeypatch.setenv("PUSH_TO_TALK_MICROPHONE", "/test/microphone")
    monkeypatch.setenv("PUSH_TO_TALK_HOTKEY", "/test/hotkey")
    monkeypatch.setenv("PUSH_TO_TALK_PASTE", "/test/paste")
    monkeypatch.setattr(ptt.subprocess, "run", run)
    assert ptt.main() == int(paste)
    assert calls == [
        ["/test/microphone", "--check"], ["/test/hotkey", "--check"],
        *([["/test/paste", "--check"]] if paste else []),
    ]


def test_paste_permission_denial_stops_before_recording(monkeypatch):
    calls = []

    def denied(command, **kwargs):
        calls.append(command)
        raise subprocess.CalledProcessError(1, command)

    monkeypatch.setattr(sys, "argv", ["push-to-talk", "--paste"])
    monkeypatch.setenv("PUSH_TO_TALK_PASTE", "/test/paste")
    monkeypatch.setattr(ptt.subprocess, "run", denied)
    monkeypatch.setattr(ptt.signal, "signal", lambda *args: None)
    assert ptt.main() == 1
    assert calls == [["/test/paste", "--authorize"]]


def test_short_tap_is_not_transcribed(make_controller):
    controller, stdout, _ = make_controller(duration=0.05)
    controller.press()
    _, path = controller.recording
    controller.release()
    controller.close()
    assert stdout.getvalue() == ""
    assert not path.exists()


@pytest.mark.parametrize("device", ["USB Audio Microphone", "BuiltInMicrophoneDevice"])
def test_selected_microphone_is_passed_as_one_argument(make_controller, device):
    controller, stdout, _ = make_controller(device=device)
    controller.press()
    controller.release()
    controller.close()
    assert stdout.getvalue() == "hello from the microphone. Another sentence.\n"


def test_microphone_discovery_does_not_request_permissions(monkeypatch):
    calls = []

    def run(command, **kwargs):
        calls.append(command)
        return subprocess.CompletedProcess(command, 0)

    monkeypatch.setattr(sys, "argv", ["push-to-talk", "--list-microphones"])
    monkeypatch.setenv("PUSH_TO_TALK_MICROPHONE", "/test/microphone")
    monkeypatch.setattr(ptt.subprocess, "run", run)
    assert ptt.main() == 0
    assert calls == [["/test/microphone", "--list"]]


def test_shutdown_discards_unreleased_recording(make_controller):
    controller, stdout, _ = make_controller()
    controller.press()
    process, path = controller.recording
    controller.close()
    assert process.poll() is not None
    assert controller.recording is None
    assert not path.exists()
    assert stdout.getvalue() == ""


def test_microphone_start_failure_is_cleaned_up(make_controller):
    controller, stdout, _ = make_controller(microphone_source="raise SystemExit(3)\n")
    with pytest.raises(RuntimeError, match="microphone did not start"):
        controller.press()
    assert controller.recording is None
    assert list(controller.directory.glob("*.wav")) == []
    assert stdout.getvalue() == ""


def test_missing_microphone(make_controller):
    controller, _, _ = make_controller()
    controller.microphone = str(controller.directory / "missing")
    with pytest.raises(FileNotFoundError):
        controller.press()
    assert controller.recording is None


def test_recording_failure_does_not_transcribe(make_controller):
    controller, stdout, _ = make_controller(microphone_source="print('READY', flush=True)\nraise SystemExit(3)\n")
    controller.press()
    process, path = controller.recording
    process.wait(timeout=5)
    with pytest.raises(RuntimeError, match="microphone failed"):
        controller.release()
    assert not path.exists()
    assert stdout.getvalue() == ""


def test_transcription_failure_is_stderr_only(make_controller):
    controller, stdout, stderr = make_controller(transcriber_source="raise SystemExit(7)\n")
    controller.press()
    _, path = controller.recording
    controller.release()
    controller.close()
    assert stdout.getvalue() == ""
    assert "transcription failed" in errors(stderr)
    assert not path.exists()


def test_transcription_timeout_cleans_audio(make_controller, monkeypatch):
    controller, stdout, stderr = make_controller()
    path = controller.directory / "timeout.wav"
    path.touch()

    def timeout(*args, **kwargs):
        raise subprocess.TimeoutExpired(args[0], 120)

    monkeypatch.setattr(ptt.subprocess, "run", timeout)
    controller.transcribe(path)
    assert stdout.getvalue() == ""
    assert "transcription failed" in errors(stderr)
    assert not path.exists()


def test_can_record_while_previous_utterance_transcribes(make_controller, tmp_path):
    started = tmp_path / "transcription started"
    gate = tmp_path / "finish transcription"
    controller, stdout, _ = make_controller(transcriber_source=f"""
from pathlib import Path
import sys
import time
Path({str(started)!r}).touch()
deadline = time.monotonic() + 5
while not Path({str(gate)!r}).exists() and time.monotonic() < deadline:
    time.sleep(0.01)
print(Path(sys.argv[-1]).stem)
""")
    controller.press()
    controller.release()
    deadline = time.monotonic() + 5
    while not started.exists() and time.monotonic() < deadline:
        time.sleep(0.01)
    assert started.exists()
    try:
        controller.press()
        assert controller.recording[0].poll() is None
        controller.release()
    finally:
        gate.touch()
        controller.close()
    assert stdout.getvalue() == "1\n2\n"
    assert list(controller.directory.glob("*.wav")) == []
