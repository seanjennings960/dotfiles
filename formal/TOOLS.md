# Pinned toolchain and reference checks

`shell.nix` and `toolchain.nix` pin nixpkgs revision
`718f670e845328e9c2cecdd832835712b2cbd065` and its unpacked SHA-256
`0jw6fc1f4p6hnpmnp6c5ga5a0xlfbba5245xnx37m1rcixd43vhi`.
The reference checks below were run on `aarch64-darwin` on 2026-10-28.

## Lean

From the repository root:

```sh
export PATH=/nix/var/nix/profiles/default/bin:$PATH
nix-shell formal/shell.nix --run 'lean --version; lake --version'
nix-shell formal/shell.nix --run 'cd formal && lake build'
```

The shell supplies **Lean 4.29.1**, **Lake 5.0.0-src+v4.29.1**, and Python.
The realized local binaries are:

```text
/nix/store/jcaahg1daq98ihbjqmmwnl07wl5p4lfa-lean4-4.29.1/bin/lean
/nix/store/jcaahg1daq98ihbjqmmwnl07wl5p4lfa-lean4-4.29.1/bin/lake
```

Both version commands were executed successfully, including inside the pinned
Nix shell. `leanprover/lean4:v4.29.1` is the matching project toolchain version.
The store path is platform-specific; the Nix expression is the portable pin.

## Reference tools

The user's "Isabella" is interpreted as **Isabelle**. Hazelnut's references
are the **Agda mechanization** and **OCaml implementation**, linked directly
from [Cyrus Omar's author page](https://www.cs.cmu.edu/~comar/hazelnut-popl17/).

| Tool | Pinned nixpkgs version | Actual check |
| --- | --- | --- |
| Agda | 2.8.0 | Fresh upstream `all.agda`: **PASS** |
| OCaml | 5.4.1 | Unmodified `hz_semantics.ml` compilation and 11 behavioral checks: **PASS** |
| OCaml consistency audit | 5.4.1 | Three paper/upstream discrepancies: **FAIL**, recorded explicitly |
| Isabelle, original input | 2025-2 | **FAIL** at legacy tactic variable `const`, line 171 |
| Isabelle, compatibility copy | 2025-2 | Complete theory, including `type_safety`: **PASS** |

Run independently or together:

```sh
nix-shell formal/shell.nix --run 'python3 formal/scripts/check-reference.py agda'
nix-shell formal/shell.nix --run 'python3 formal/scripts/check-reference.py ocaml'
nix-shell formal/shell.nix --run 'python3 formal/scripts/check-reference.py isabelle'
nix-shell formal/shell.nix --run 'python3 formal/scripts/check-reference.py isabelle --isabelle-compat'
nix-shell formal/shell.nix --run 'python3 formal/scripts/check-reference.py'
```

The script realizes each tool using `nix-build formal/toolchain.nix -A TOOL
--no-out-link`, verifies archive hashes, extracts fresh source directories, and
saves exact commands, working directories, output, and exit statuses in
`reference/logs/`. A nonzero reference status makes the script return nonzero;
it continues checking other requested references. The OCaml audit returns 1
because it exposes real upstream discrepancies. The unmodified Isabelle
source returns 1 because of the proof-script compatibility issue below.

For an interactive shell containing all three references:

```sh
nix-shell formal/shell.nix --arg references true
```

Downloads, extracted sources, interface files, executables, Isabelle user
state, and scratch files stay under ignored `reference/` subdirectories.
Nix-managed compilers reside in `/nix/store`.

## Source provenance and scope

All revisions and archive SHA-256 values are in
[`reference/sources.json`](reference/sources.json).

### Hazelnut Agda

- Repository: <https://github.com/hazelgrove/agda-popl17>
- Revision: `db3d21a1e3f17ef77ad557ed12374979f381b6b7` (2021-07-11).
- This is the core calculus master branch, including the authors' Agda 2.6.2
  syntax update. Its unmodified sources also typecheck with our Agda 2.8.0.
- `agda --no-libraries all.agda` checks all imported modules from a fresh
  extraction, including action sensibility, movement, reachability,
  constructability, determinism, structural properties, and paper examples.
- Upstream `Prelude.agda:83–85` postulates dependent function extensionality.
  This is an explicit upstream assumption, so the result is not an Agda
  `--safe` verification. No new postulates or holes were added.
- The sums branch and author-site historical ZIP releases were not checked.

### Hazelnut OCaml

- Repository: <https://github.com/hazelgrove/HZ>
- Revision: `2ec8a4ce37a3c1f6f6cacb2fc3a2421ae3126090` (2017-09-04).
- The pure semantics module compiles unmodified with OCaml 5.4.1.
- `reference/hz_checks.ml` executes construction of `1 + 2`, rechecks the
  synthesized type after each edit, checks identity typing and movement
  erasure, and checks incompatible-term wrapping, rejected finish, and deletion.
- These are command-line OCaml semantics checks. The historical js_of_ocaml/TyXML
  browser UI build is not part of the result.

The audit independently expresses componentwise type consistency from the
paper. Upstream `src/hz_semantics.ml:24–27` instead compares each arrow/sum's
own two components. Executing the unchanged upstream code demonstrates:

| Types compared | Paper | Upstream |
| --- | --- | --- |
| `num → num` and `(num → num) → (num → num)` | false | true |
| `num → (num → num)` and `num → (? → num)` | true | false |
| `num + num` and `(num → num) + (num → num)` | false | true |

The executable audit preserves these failures in
[`reference/logs/ocaml-consistency-audit.log`](reference/logs/ocaml-consistency-audit.log).
The upstream implementation therefore cannot serve as an unconditional
semantic oracle for the Lean definitions.

### Isabelle input

The original `/Users/sean/Downloads/EvalSTLC.thy` is read only. The checker
requires its recorded SHA-256:

```text
21645ca95604799eb56392bf5a8f98eea49fd2ca0ab864e93076671ed69dbc76
```

It creates an isolated mode-0444 copy and `ROOT` session below `reference/work/`,
builds against `HOL`, and checks both original and copy hashes afterward.
To use the same bytes at a different location, pass
`--eval-stlc /path/to/EvalSTLC.thy`.

The unmodified source fails at line 171 with `Cannot determine type of
"const"`. The old `case_tac const` relies on a generated variable name that
differs in Isabelle2025-2. `--isabelle-compat` applies
[`reference/EvalSTLC-Isabelle2025-2.patch`](reference/EvalSTLC-Isabelle2025-2.patch)
to a fresh copy. It replaces only the proof of `delta_safe` with named local
subgoals and constructor cases. Definitions and theorem statements retain
their original contents. The complete patched theory builds successfully,
including `interp_safe` and `type_safety`, without admitted proofs.

The original SHA-256 remains the value above. The successful compatibility
copy has SHA-256
`752e858ad9a994efc955d4b5e39a1998940be7a50a04326b19a6e2a5f5ff51e1`.
The original failure, patched success, and both source hash checks are saved
in `reference/logs/isabelle-{check,source}.log` and
`reference/logs/isabelle-compat-{check,source}.log`. An initial shorter proof
attempt left three unproved subgoals; its exact patch and failure are retained
as `reference/logs/isabelle-compat-initial-proof.patch` and
`reference/logs/isabelle-compat-initial-proof-failure.log`.

## Setup attempts and logs

Initial discovery used the existing root shell's `nixos-26.05` URL to identify
versions. The final expression uses the immutable revision and source hash.
The initial realization commands were:

```sh
/nix/var/nix/profiles/default/bin/nix-build --no-out-link --expr \
  'let p = import /nix/store/z40fynbhnw0d06q05mw2mznn49h1y9pk-source {}; in p.lean4'
/nix/var/nix/profiles/default/bin/nix-build --no-out-link --expr \
  'let p = import /nix/store/z40fynbhnw0d06q05mw2mznn49h1y9pk-source {}; in [p.agda p.ocaml]'
/nix/var/nix/profiles/default/bin/nix-build --no-out-link --expr \
  'let p = import /nix/store/z40fynbhnw0d06q05mw2mznn49h1y9pk-source {}; in p.isabelle'
/nix/var/nix/profiles/default/bin/nix-prefetch-url --unpack \
  https://github.com/NixOS/nixpkgs/archive/718f670e845328e9c2cecdd832835712b2cbd065.tar.gz
```

- Lean and Agda/OCaml were substituted successfully from `cache.nixos.org`.
- The first Isabelle download exceeded the tool's 120-second execution limit;
  `nix-isabelle-realize-timeout.log` records the interrupted attempt. The
  checker retried without that execution limit and installed Isabelle2025-2
  successfully at
  `/nix/store/18ygg3r4ji4h5m91cci80b6g897b1b40-isabelle-2025-2`.
- The first script invocation hit macOS Python's lack of `tarfile`'s newer
  `filter` argument. The script now validates archive members explicitly and
  works on that Python; the original exceptions remain in the two
  `*-initial-python-compatibility-error.log` files. Subsequent Agda and OCaml
  runs reached the actual compilers successfully.
