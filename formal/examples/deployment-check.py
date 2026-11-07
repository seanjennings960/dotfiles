#!/usr/bin/env python3
"""Check real Nix semantics and derivation plans using isolated local stores.

With --native, also build and run tiny applications, activate/rollback temporary
profiles, and test native GC roots. Every store/profile is temporary; no daemon,
downloads, real user/system profile changes, or real-store GC.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


HERE = Path(__file__).resolve().parent


def nix_tool(name):
    # NIX_STORE is a standard nix-shell variable naming the store DIRECTORY,
    # so executable overrides must use a separate, unambiguous namespace.
    explicit = os.environ.get("FORMAL_" + name.upper().replace("-", "_"))
    path = explicit or shutil.which(name)
    if not path:
        fallback = Path("/nix/var/nix/profiles/default/bin") / name
        if fallback.exists():
            path = str(fallback)
    if not path:
        raise RuntimeError(f"{name} is required (use formal/shell.nix or set PATH)")
    if not Path(path).is_file() or not os.access(path, os.X_OK):
        raise RuntimeError(f"{name} executable is not runnable: {path}")
    return path


def run(argv, *, expected_error=None, env=None):
    result = subprocess.run(argv, text=True, capture_output=True, timeout=30, env=env)
    if expected_error:
        if result.returncode == 0 or expected_error not in result.stderr:
            raise AssertionError(f"Expected {expected_error!r}: {result.stdout}\n{result.stderr}")
        return None
    if result.returncode:
        raise RuntimeError(f"{' '.join(argv)}\n{result.stderr}")
    return result.stdout


def native_demo(temp_parent):
    """Use a non-diverted local store so native builds also work on macOS."""
    instantiate = nix_tool("nix-instantiate")
    nix_store = nix_tool("nix-store")
    nix_env = nix_tool("nix-env")
    # A short state path also fits Darwin's Unix-domain socket path limit.
    with tempfile.TemporaryDirectory(prefix="n-", dir=temp_parent) as directory:
        root = Path(directory).resolve()
        store_dir, state_dir, log_dir = root / "o", root / "s", root / "l"
        store = f"local?store={store_dir}&state={state_dir}&log={log_dir}"
        env = os.environ.copy()
        env.update({
            "HOME": str(root / "h"), "XDG_CACHE_HOME": str(root / "cache"),
            "XDG_CONFIG_HOME": str(root / "conf"), "NIX_CONF_DIR": str(root / "conf"),
            "NIX_USER_CONF_FILES": "", "NIX_CONFIG": "", "NIX_PATH": "", "NIX_PROFILES": "",
            "NIX_STORE_DIR": str(store_dir), "NIX_STATE_DIR": str(state_dir),
            "NIX_LOG_DIR": str(log_dir), "NIX_REMOTE": store,
        })
        (root / "h").mkdir()
        (root / "conf").mkdir()
        common = ["--store", store,
                  "--option", "substituters", "", "--option", "builders", "",
                  "--option", "build-users-group", "", "--option", "sandbox", "false",
                  "--option", "max-jobs", "1", "--option", "keep-outputs", "false",
                  "--option", "keep-derivations", "false"]

        def invoke(tool, *args, expected_error=None):
            return run([tool, *common, *map(str, args)], expected_error=expected_error, env=env)

        expression = f"(import (builtins.toPath {json.dumps(str(HERE / 'deployment-plan.nix'))})) {{}}"
        plan = json.loads(invoke(instantiate, "--eval", "--strict", "--json",
                                 "--read-write-mode", "--expr", expression))["plans"]
        outputs = {name: Path(p["outputPath"]) for name, p in plan.items()}
        if any(p.parent != store_dir for p in outputs.values()):
            raise AssertionError("Native build outputs must belong to the disposable store")
        invoke(nix_store, "--realise", *[p["derivationPath"] for p in plan.values()])
        for name in ("aliceV1", "aliceV2", "bob"):
            closure = set(invoke(nix_store, "--query", "--requisites", outputs[name]).splitlines())
            if closure != {str(outputs[name]), str(outputs["runtime"])}:
                raise AssertionError(f"Wrong runtime closure for {name}: {closure}")
        print("PASS: native builds of runtime + 3 applications; exact runtime closures checked")

        profiles = state_dir / "profiles"
        profiles.mkdir(exist_ok=True)
        alice, bob = profiles / "alice", profiles / "bob"

        def set_profile(profile, target):
            invoke(nix_env, "--profile", profile, "--set", target)

        def check_active(profile, target, expected):
            if profile.resolve(strict=True) != target:
                raise AssertionError(f"Incorrect active generation for {profile.name}")
            result = run([str(profile / "bin/run")], env=env)
            if result != expected:
                raise AssertionError(f"Wrong runnable application output: {result!r}")

        alice_v1_text = "Alice editor 1\nshared runtime\n"
        alice_v2_text = "Alice editor 2\nshared runtime\n"
        bob_text = "Bob analysis\nshared runtime\n"
        set_profile(alice, outputs["aliceV1"])
        set_profile(bob, outputs["bob"])
        check_active(alice, outputs["aliceV1"], alice_v1_text)
        check_active(bob, outputs["bob"], bob_text)
        bob_link = os.readlink(bob)
        runtime_hash = hashlib.sha256((outputs["runtime"] / "message").read_bytes()).hexdigest()

        # A failed native build cannot publish a partial profile generation.
        failed_expr = '''builtins.derivation {
          name = "formal-failed-build"; system = builtins.currentSystem;
          builder = "/bin/sh";
          args = [ "-c" "echo deliberate-build-failure >&2; exit 23" ];
        }'''
        failed_drv = invoke(instantiate, "--expr", failed_expr).strip()
        invoke(nix_store, "--realise", failed_drv, expected_error="exit code 23")
        check_active(alice, outputs["aliceV1"], alice_v1_text)
        print("PASS: failed native build leaves the active Alice generation runnable")

        set_profile(alice, outputs["aliceV2"])
        check_active(alice, outputs["aliceV2"], alice_v2_text)
        check_active(bob, outputs["bob"], bob_text)
        if os.readlink(bob) != bob_link:
            raise AssertionError("Alice activation changed Bob's profile link")
        invoke(nix_env, "--profile", alice, "--rollback")
        check_active(alice, outputs["aliceV1"], alice_v1_text)
        check_active(bob, outputs["bob"], bob_text)
        print("PASS: native per-profile activation, Alice rollback, and Bob noninterference")

        # Retained inactive generations are genuine native Nix GC roots.
        invoke(nix_store, "--gc")
        if not outputs["aliceV2"].is_dir():
            raise AssertionError("GC removed a retained rollback generation")

        staged = root / "staged-bob"
        invoke(nix_store, "--realise", outputs["aliceV2"], "--add-root", staged, "--indirect")
        invoke(nix_env, "--profile", alice, "--delete-generations", "2")

        unused_expr = '''builtins.derivation {
          name = "formal-unused-build"; system = builtins.currentSystem;
          builder = "/bin/sh";
          args = [ "-eu" "-c" "/bin/mkdir -p $out; printf unused > $out/message" ];
        }'''
        unused_drv = invoke(instantiate, "--expr", unused_expr).strip()
        unused = Path(invoke(nix_store, "--realise", unused_drv).strip())
        if unused.parent != store_dir:
            raise AssertionError("Unreferenced build escaped the disposable store")
        invoke(nix_store, "--gc")
        if unused.exists() or not outputs["aliceV2"].exists():
            raise AssertionError("GC must remove garbage while protecting Bob's staged root")
        check_active(alice, outputs["aliceV1"], alice_v1_text)
        check_active(bob, outputs["bob"], bob_text)
        print("PASS: native GC retains saved/staged generations and removes an unused build")

        staged.unlink()
        invoke(nix_store, "--gc")
        if outputs["aliceV2"].exists():
            raise AssertionError("Dropped generation remained after its last root was removed")
        check_active(alice, outputs["aliceV1"], alice_v1_text)
        check_active(bob, outputs["bob"], bob_text)
        if os.readlink(bob) != bob_link:
            raise AssertionError("GC or Alice rollback changed Bob's profile link")
        if hashlib.sha256((outputs["runtime"] / "message").read_bytes()).hexdigest() != runtime_hash:
            raise AssertionError("Shared runtime bytes changed")
        print("PASS: removing the final staged root collects v2; both active apps and shared bytes survive")
    print("PASS: native demo store, database, logs, HOME, and profiles removed")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native", action="store_true", help="also run isolated native builds/profiles/GC")
    args = parser.parse_args()
    instantiate = nix_tool("nix-instantiate")
    nix = nix_tool("nix")
    print(run([nix, "--version"]).strip())
    preferred_tmp = (Path(tempfile.gettempdir()) / "opencode").resolve()
    temp_parent = preferred_tmp if preferred_tmp.is_dir() else None
    with tempfile.TemporaryDirectory(prefix="formal-nix-", dir=temp_parent) as directory:
        store = f"local?root={Path(directory).resolve()}"
        common = ["--store", store, "--option", "substituters", "", "--option", "builders", ""]
        evaluate = [instantiate, *common, "--eval", "--strict", "--json"]
        semantics = json.loads(run([*evaluate, str(HERE / "nix-semantics.nix")]))
        failed = [name for name, passed in semantics["checks"].items() if passed is not True]
        if failed:
            raise AssertionError(f"Nix checks failed: {failed}")
        print(f"PASS: {len(semantics['checks'])} real-Nix scope/laziness/default/forcing checks")
        print("OBSERVATION: same-size different-domain equality = " +
              json.dumps(semantics["observations"]["sameSizeDomainMismatch"], sort_keys=True))
        print("OBSERVATION: native function equality = " +
              json.dumps(semantics["observations"]["functionEquality"]))
        isolated_domain_probe = (
            'let bad = throw "domain-probe"; in builtins.tryEval '
            '({ a = bad; b = 1; } == { a = bad; c = 2; })'
        )
        isolated_domain = json.loads(run([*evaluate, "--expr", isolated_domain_probe]))
        print("OBSERVATION: isolated same-size domain probe = " +
              json.dumps(isolated_domain, sort_keys=True))

        # Process failures are distinct from our finite-fuel Lean timeouts.
        faults = [
            ("(1 2)", "not a function"),
            ("{ a = 1; }.missing", "attribute 'missing' missing"),
            ("({ a }: a) { a = 1; extra = 2; }", "unexpected argument"),
            ("({ a ? a }: a) {}", "infinite recursion"),
            ("builtins.deepSeq { a = throw \"deep-fixture\"; } true", "deep-fixture"),
        ]
        for expression, message in faults:
            run([*evaluate, "--expr", expression], expected_error=message)
        print(f"PASS: {len(faults)} expected evaluator failures (including detected recursion)")

        plan_expr = f"(import (builtins.toPath {json.dumps(str(HERE / 'deployment-plan.nix'))})) {{}}"
        plan = json.loads(run([*evaluate, "--read-write-mode", "--expr", plan_expr]))
        plans = plan["plans"]
        paths = [p["outputPath"] for p in plans.values()]
        if len(set(paths)) != 4:
            raise AssertionError("Side-by-side versions/users must have distinct output paths")
        if plan["users"]["alice"]["desired"] != plans["aliceV2"]["outputPath"]:
            raise AssertionError("Alice's desired generation does not match v2")
        if plan["users"]["bob"]["desired"] != plans["bob"]["outputPath"]:
            raise AssertionError("Bob's desired generation does not match his application")

        show = [nix, "--extra-experimental-features", "nix-command", *common, "derivation", "show"]
        runtime_drv = plans["runtime"]["derivationPath"]
        for name in ("aliceV1", "aliceV2", "bob"):
            drv = plans[name]["derivationPath"]
            details = json.loads(run([*show, drv]))
            # Nix 2.33+ wraps derivation entries in { derivations, version }.
            derivations = details.get("derivations", details)
            entry = derivations.get(drv, derivations.get(Path(drv).name))
            if entry is None:
                raise AssertionError(f"Unexpected derivation JSON schema: {details}")
            inputs = entry.get("inputDrvs", entry.get("inputs", {}).get("drvs"))
            if inputs is None:
                raise AssertionError(f"Unexpected derivation input schema: {entry}")
            if runtime_drv not in inputs and Path(runtime_drv).name not in inputs:
                raise AssertionError(f"{name} lost its declared runtime dependency: {inputs}")
        print("PASS: 4 distinct derivation plans; all 3 user versions share the runtime input")
        print("PASS: plan-only temporary store cleaned up on exit")
    if args.native:
        native_demo(temp_parent)


if __name__ == "__main__":
    main()
