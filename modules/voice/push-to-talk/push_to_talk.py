"""macOS push-to-talk: physical key events -> microphone WAV -> transcriber stdout."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import selectors
import shlex
import signal
import subprocess
import sys
import tempfile
import wave


KEYS = {"caps-lock": 0x39, "right-option": 0xE6, "f18": 0x6D}


def terminate(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


class PushToTalk:
    def __init__(self, directory, microphone, transcriber, stdout=None, stderr=None, device=None):
        self.directory = Path(directory)
        self.microphone = microphone
        self.transcriber = transcriber
        self.device = device
        self.stdout = stdout if stdout is not None else sys.stdout
        self.stderr = stderr if stderr is not None else sys.stderr
        self.recording = None
        self.sequence = 0
        # Serial transcription preserves utterance order without blocking key releases.
        self.worker = ThreadPoolExecutor(max_workers=1)

    def log(self, message):
        print(f"push-to-talk: {message}", file=self.stderr, flush=True)

    def press(self):
        if self.recording is not None:  # Ignore repeats and duplicate key-down events.
            return
        self.sequence += 1
        path = self.directory / f"{self.sequence}.wav"
        command = [self.microphone]
        if self.device is not None:
            command.extend(["--device", self.device])
        process = subprocess.Popen(
            [*command, str(path)], stdout=subprocess.PIPE,
            stderr=self.stderr, text=True, start_new_session=True,
        )
        self.recording = process, path
        try:
            with selectors.DefaultSelector() as selector:
                selector.register(process.stdout, selectors.EVENT_READ)
                if not selector.select(timeout=10) or process.stdout.readline().strip() != "READY":
                    raise RuntimeError("microphone did not start")
            self.log("recording; release the key to transcribe")
        except BaseException:
            self.discard()
            raise
        finally:
            process.stdout.close()

    def release(self):
        if self.recording is None:
            return
        process, path = self.recording
        self.recording = None
        try:
            if process.poll() is None:
                process.send_signal(signal.SIGINT)
            if process.wait(timeout=5) != 0:
                raise RuntimeError("microphone failed")
            with wave.open(str(path), "rb") as audio:
                duration = audio.getnframes() / audio.getframerate()
            if duration < 0.15:
                path.unlink(missing_ok=True)
                return
            self.worker.submit(self.transcribe, path)
        except BaseException:
            terminate(process)
            path.unlink(missing_ok=True)
            raise

    def transcribe(self, path):
        try:
            result = subprocess.run(
                [*self.transcriber, str(path)], stdout=subprocess.PIPE,
                stderr=self.stderr, text=True, check=True, timeout=120,
                start_new_session=True,
            )
            text = " ".join(result.stdout.split())
            if text:
                print(text, file=self.stdout, flush=True)
        except (OSError, subprocess.SubprocessError) as error:
            self.log(f"transcription failed: {error}")
        finally:
            path.unlink(missing_ok=True)

    def discard(self):
        if self.recording is not None:
            process, path = self.recording
            self.recording = None
            terminate(process)
            path.unlink(missing_ok=True)

    def close(self):
        self.discard()
        # Already released utterances finish; an unreleased recording is discarded.
        self.worker.shutdown(wait=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--key", choices=KEYS, default="caps-lock")
    parser.add_argument("--microphone", help="microphone UID or exact name (default: macOS default input)")
    parser.add_argument("--list-microphones", action="store_true", help="discover microphone UIDs and names without recording")
    parser.add_argument(
        "--transcriber", default="transcribe",
        help="command (no shell); the recorded WAV path is appended",
    )
    parser.add_argument("--check", action="store_true", help="inspect permissions without requesting access")
    args = parser.parse_args()
    transcriber = shlex.split(args.transcriber)
    if not transcriber:
        parser.error("--transcriber must not be empty")
    microphone = os.environ.get("PUSH_TO_TALK_MICROPHONE", "microphone")
    hotkey = os.environ.get("PUSH_TO_TALK_HOTKEY", "ptt-hotkey")
    if args.list_microphones:
        return subprocess.run([microphone, "--list"], check=False).returncode
    if args.check:
        mic = subprocess.run([microphone, "--check"], check=False).returncode
        key = subprocess.run([hotkey, "--check"], check=False).returncode
        return int(bool(mic or key))

    def interrupted(number, frame):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, interrupted)
    events = None
    status = 0
    with tempfile.TemporaryDirectory(prefix="push-to-talk-") as directory:
        ptt = PushToTalk(directory, microphone, transcriber, device=args.microphone)
        try:
            subprocess.run([microphone, "--authorize"], check=True)
            events = subprocess.Popen(
                [hotkey, str(KEYS[args.key])], stdout=subprocess.PIPE,
                text=True, start_new_session=True,
            )
            for line in events.stdout:
                event = line.strip()
                if event == "READY":
                    ptt.log(f"hold {args.key} to talk; Ctrl-C to quit")
                elif event == "DOWN":
                    ptt.press()
                elif event == "UP":
                    ptt.release()
                else:
                    raise RuntimeError(f"unexpected hotkey event: {event!r}")
            raise RuntimeError(f"hotkey listener exited ({events.wait()})")
        except KeyboardInterrupt:
            pass
        except (OSError, RuntimeError, subprocess.SubprocessError, wave.Error) as error:
            ptt.log(str(error))
            status = 1
        finally:
            if events is not None:
                terminate(events)
                events.stdout.close()
            ptt.close()
    return status


if __name__ == "__main__":
    sys.exit(main())
