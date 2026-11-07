#!/usr/bin/env python3
"""Run pinned upstream references; keep sources, commands, and logs in formal/."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tarfile
import tempfile

FORMAL = Path(__file__).resolve().parents[1]
REFERENCE = FORMAL / "reference"
SOURCES = json.loads((REFERENCE / "sources.json").read_text())
LOGS = REFERENCE / "logs"
WORK = REFERENCE / "work"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(name, argv, cwd=FORMAL, env=None):
    """Return the actual process exit status and save its unfiltered output."""
    command = shlex.join(map(str, argv))
    print(f"[{name}] {command}", flush=True)
    result = subprocess.run(list(map(str, argv)), cwd=cwd, env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    (LOGS / f"{name}.log").write_text(
        f"cwd: {cwd}\ncommand: {command}\n"
        + (f"environment overrides: {json.dumps({k: env[k] for k in ['HOME', 'USER_HOME', 'TMPDIR']})}\n"
           if env is not None else "")
        + result.stdout + f"\nexit status: {result.returncode}\n")
    print(result.stdout, end="", flush=True)
    return result


def tool(name):
    nix_build = shutil.which("nix-build") or "/nix/var/nix/profiles/default/bin/nix-build"
    result = run(f"install-{name}",
                 [nix_build, FORMAL / "toolchain.nix", "-A", name, "--no-out-link"])
    if result.returncode:
        raise RuntimeError(f"Nix realization failed for {name}; see logs")
    # Nix progress is on stderr; the final stdout line is the output store path.
    paths = [line for line in result.stdout.splitlines() if line.startswith("/nix/store/")]
    return Path(paths[-1]) / "bin"


def source(name):
    pin = SOURCES[name]
    downloads = REFERENCE / "downloads"
    downloads.mkdir(exist_ok=True)
    archive = downloads / f"{name}-{pin['revision']}.tar.gz"
    if not archive.exists():
        result = run(f"download-{name}",
                     ["curl", "--fail", "--location", "--retry", "2", pin["url"], "-o", archive])
        if result.returncode:
            raise RuntimeError(f"Download failed for {name}")
    actual = digest(archive)
    if actual != pin["sha256"]:
        raise RuntimeError(f"{archive}: expected {pin['sha256']}, got {actual}")
    directory = Path(tempfile.mkdtemp(prefix=f"{name}-", dir=WORK))
    with tarfile.open(archive) as tar:
        # Also support the macOS system Python, which predates tarfile filters.
        for member in tar.getmembers():
            path = Path(member.name)
            if path.is_absolute() or ".." in path.parts or not (member.isfile() or member.isdir()):
                raise RuntimeError(f"Unexpected archive member: {member.name}")
        tar.extractall(directory)
    (LOGS / f"source-{name}.log").write_text(
        json.dumps(pin, indent=2) + f"\nverified archive sha256: {actual}\nextracted: {directory}\n")
    return directory / pin["directory"]


def agda():
    binary = tool("agda") / "agda"
    run("agda-version", [binary, "--version"])
    return run("agda-check", [binary, "--no-libraries", "all.agda"], source("agda")).returncode


def ocaml():
    binary = tool("ocaml") / "ocamlc"
    run("ocaml-version", [binary, "-version"])
    directory = source("ocaml") / "src"
    shutil.copyfile(REFERENCE / "hz_checks.ml", directory / "hz_checks.ml")
    result = run("ocaml-build", [binary, "-o", "hz_checks", "hz_semantics.ml", "hz_checks.ml"], directory)
    if result.returncode:
        return result.returncode
    smoke = run("ocaml-smoke", [directory / "hz_checks", "smoke"], directory)
    audit = run("ocaml-consistency-audit", [directory / "hz_checks", "audit"], directory)
    return smoke.returncode or audit.returncode


def isabelle(original, compatible=False):
    expected = SOURCES["isabelle"]["sha256"]
    if digest(original) != expected:
        raise RuntimeError("EvalSTLC.thy differs from the recorded source; refusing an unrecorded input")
    binary = tool("isabelle") / "isabelle"
    directory = Path(tempfile.mkdtemp(prefix="isabelle-", dir=WORK))
    copied = directory / "EvalSTLC.thy"
    shutil.copyfile(original, copied)
    label = "isabelle-compat" if compatible else "isabelle"
    if compatible:
        result = run(f"{label}-patch", ["patch", "-p0", "-i",
                     REFERENCE / "EvalSTLC-Isabelle2025-2.patch"], directory)
        if result.returncode:
            return result.returncode
    copied.chmod(0o444)
    shutil.copyfile(REFERENCE / "ROOT", directory / "ROOT")
    home = REFERENCE / "home"
    tmp = REFERENCE / "tmp"
    home.mkdir(exist_ok=True)
    tmp.mkdir(exist_ok=True)
    env = os.environ | {"HOME": str(home), "USER_HOME": str(home), "TMPDIR": str(tmp)}
    run(f"{label}-version", [binary, "version"], env=env)
    result = run(f"{label}-check", [binary, "build", "-v", "-j", "1", "-o", "threads=2",
                                   "-D", directory], env=env)
    after = digest(original)
    (LOGS / f"{label}-source.log").write_text(
        f"original (opened read-only): {original}\ncopy (mode 0444): {copied}\n"
        f"before sha256: {expected}\nafter sha256: {after}\ncopy sha256: {digest(copied)}\n")
    if after != expected or (not compatible and digest(copied) != expected):
        raise RuntimeError("Source hash changed during the check")
    return result.returncode


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("targets", nargs="*", metavar="{agda,ocaml,isabelle}")
    parser.add_argument("--eval-stlc", type=Path, default=Path(SOURCES["isabelle"]["original"]))
    parser.add_argument("--isabelle-compat", action="store_true",
                        help="apply the recorded Isabelle2025-2 proof compatibility patch to a fresh copy")
    args = parser.parse_args()
    for target in args.targets:
        if target not in ("agda", "ocaml", "isabelle"):
            parser.error(f"unknown reference: {target}")
    LOGS.mkdir(exist_ok=True)
    WORK.mkdir(exist_ok=True)
    failures = {}
    for target in args.targets or ["agda", "ocaml", "isabelle"]:
        try:
            status = isabelle(args.eval_stlc, args.isabelle_compat) if target == "isabelle" else globals()[target]()
        except Exception as error:
            status = 1
            print(f"{target}: {error}", flush=True)
            (LOGS / f"{target}-error.log").write_text(f"{type(error).__name__}: {error}\n")
        failures[target] = status
    print(json.dumps(failures, indent=2))
    raise SystemExit(int(any(failures.values())))


if __name__ == "__main__":
    main()
