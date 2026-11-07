# Constructive soundness and two executable applications

**The key result:** the supplied nonrecursive STLC satisfies the original
Isabelle type-safety theorem constructively. For the blog's recursive
language, evaluation is a coherent partial value whose every returned
observation is typed. This supplies soundness without deciding termination.

## Check

From this directory:

```sh
nix-shell --run 'python3 scripts/check.py'
```

The pinned Nix shell supplies Lean **4.29.1**. The project uses `Std`, with no
Mathlib or external Lean dependencies. The checker builds the development and
audits every imported project declaration, including private helpers. Anonymous
examples are kernel-checked during compilation. Only `propext` and `Quot.sound`
are allowed by the audit; classical
choice, proof holes, and native-evaluation axioms fail the audit.
It then executes the editor traces, the Lean deployment scenario, and the
native Nix builds/profile/rollback/GC demonstration in disposable stores.
The complete command passes; see [CHECKS.md](CHECKS.md) and
[verification.log](verification.log) for the results and exact output.

## Read the proof

1. [STLC.md](STLC.md): definition-by-definition correspondence with the supplied
   `EvalSTLC.thy`, including its natural numbers, metadata, and evaluation order.
2. [SOUNDNESS.md](SOUNDNESS.md): the constructive evaluation definition and the
   precise logical cost of an unrestricted termination/divergence split.
3. [NORMALIZATION.md](NORMALIZATION.md): the logical relation that proves the
   supplied STLC's original theorem, with **zero axiom dependencies**.
4. [RECURSIVE.md](RECURSIVE.md): the blog's named recursive functions, three
   safety lemmas, fuel stability, and a universally proved divergent example.

The core interpreter proof is `STLC.interp_safe` in
[`Formal/STLC.lean`](Formal/STLC.lean). The corresponding recursive proof is
`Recursive.interp_safe` in [`Formal/Recursive.lean`](Formal/Recursive.lean).
Both are short fuel inductions, including intermediate timeouts.

The constructive whole-program conclusion in
[`Formal/Soundness.lean`](Formal/Soundness.lean) is a definition:

```lean
def soundness (he : HasType Γ e T) (hρ : EnvTyped Γ ρ) :
    Partial {v : Value // ValueTyped v T} :=
  (evaluation e ρ).values (evaluation_safe he hρ)
```

`soundness_exact` proves that forgetting certificates recovers **exactly** the
interpreter's observations. Untyped faults remain visible faults. Source
observation equivalences establish agreement on both returns and divergence.
The certified computation itself is executable: its checked example is pending
at fuel 0 and returns the certified number 42 at fuel 4.

## Applications

* [EDITOR.md](EDITOR.md): Hazelnut typing and actions, reactive editing, and
  language-server definition navigation. Core statics are translated in full;
  the deterministic expression editor has the precise action boundaries listed
  there. The protocol implementation is a typed semantic model.
* [NIX.md](NIX.md): NixLang reduction, interpreter observations, and multi-user
  deployment invariants connected to Chapter 1 of Dolstra's thesis. This includes
  a proved NixLang fragment, a separate deployment model, and real Nix tests.

These demonstrate different soundness obligations: typed interpreter results,
type-preserving edits, correct name resolution, interpreter/reduction
correspondence, and safe store/profile transitions. Their exact statements
and modeled boundaries are given with the implementations.

## Independent reference checks

[TOOLS.md](TOOLS.md) records source hashes, compiler versions, commands, and
logs for Isabelle, Hazelnut Agda, and Hazelnut OCaml. The complete upstream
Agda development checks. The complete Isabelle theory checks after a local
legacy-tactic compatibility patch; the original file is preserved. OCaml
behavior checks pass, while a separate consistency audit exposes three
upstream discrepancies with the paper. Those failures are retained explicitly.
