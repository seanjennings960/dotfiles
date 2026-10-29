# Verification record

Checked on **2026-10-28**, `aarch64-darwin`.

```sh
cd formal
nix-shell --run 'python3 scripts/check.py'
```

**Result: PASS.** Complete output: [verification.log](verification.log).

| Check | Result |
| --- | --- |
| Pinned Nix Lean 4.29.1, all nine library modules and umbrella | Build passes |
| Transitive axiom audit of all 3,992 imported library declarations | Only `propext`, `Quot.sound`; no choice, proof holes, project axioms, or native proof shortcuts |
| Original STLC safety theorem via constructive termination | Zero axiom dependencies |
| Recursive-language safety and certified partial evaluation | Checked, including exact source-observation correspondence |
| Generic termination/delay dichotomy versus LPO | Both constructive implications checked |
| Hazelnut synthesis/analysis checker equivalence | Checked against declarative core typing |
| Expression/type movement erasure and editor sensibility | Checked for the documented action implementation |
| Reactive editing and LSP definition navigation | Increment trace and 16-action shadowing construction pass |
| Definition service edge cases | Holes, shadowing, UTF-16, capability fallback, incorrect targets, stale and superseded responses pass |
| Nix fragment | Independent step/interpreter correspondence and all-fuel divergence characterization checked |
| Deployment transitions | Store closure, immutable publication, staging, generations, rollback, other-user preservation, GC reachability checked |
| Native Nix 2.34.9+1 semantic fixtures | 26 assertions and five expected evaluator failures pass |
| Native derivations | Four distinct plans, three shared-runtime dependency edges, builds and runnable applications pass |
| Native profiles | Alice upgrade/rollback and failed-build isolation; Bob unchanged |
| Native GC in disposable store | Retained/staged generations survive; unreferenced output is collected; active applications remain runnable |

The native checks deliberately distinguish paper/native compatibility
observations from asserted agreement. In particular, the isolated and embedded
same-size/different-domain equality probes produce different error behavior;
direct function equality faults in the model but returns `false` in native Nix.
See [NIX.md](NIX.md#laziness-shallowdeep-evaluation-and-faults).

## Reference tools

The independent checks in [TOOLS.md](TOOLS.md) record:

* Complete upstream Hazelnut Agda development: **PASS**, with its documented
  function-extensionality postulate.
* Upstream OCaml semantics compilation and 11 behavior checks: **PASS**.
* OCaml consistency audit: **three upstream discrepancies**, preserved in logs.
* Original Isabelle input on Isabelle2025-2: legacy tactic failure.
* Separately patched compatibility copy: complete theory **PASS**, including
  `type_safety`; original file hash unchanged.

## Integration iteration

The initial aggregate run passed Lean and editor checks but exposed an executable
lookup bug: `nix-shell` exports `NIX_STORE=/nix/store`, which the native runner
had mistaken for a binary override. The runner now uses `FORMAL_NIX_*` overrides
and checks executable paths. The original failure is retained in
[verification-initial.log](verification-initial.log); the documented command
then passed end to end.

The source maps in [EDITOR.md](EDITOR.md) and [NIX.md](NIX.md) specify exactly
which calculus fragments and implementation contracts these checks establish.
