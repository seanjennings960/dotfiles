# Constructive termination of the supplied STLC

`Formal/Normalization.lean` proves that every closed well-typed expression in
`/Users/sean/Downloads/EvalSTLC.thy` successfully evaluates with some finite fuel.
It imports the faithful translation in `Formal/STLC.lean` and uses its unchanged
syntax, typing, interpreter, and observation relation.

**The original Isabelle type-safety disjunction does not require classical
reasoning for this language.** The source proof splits on whether all fuel
budgets time out, but that proof technique is unnecessary: typed programs in
this nonrecursive STLC terminate. At the two observable base types the
termination branch always holds.

## Checked results

All names below are in `STLC.Normalization`:

- `fundamental`: if `WtExpr Γ e t` and `ReducibleEnv Γ ρ`, then there are `k` and
  `v` with `interp e ρ k = .result v` and `Reducible t v`.
- `closed_terminates`: every closed well-typed expression successfully evaluates
  to a well-typed value, at every simple type (including function types).
- `base_terminates`: if its type is `Ty.int` or `Ty.bool`, there are `k`, `i`, and
  `c` with `interp e [] k = .result (.const i c)` and `typeof c = t`.
- `type_safety`: precisely the source's conclusion,
  `Eval e .diverge ∨ ∃ c, Eval e (.const c) ∧ typeof c = t`, under its closed
  typing and base-type assumptions. The proof constructs `Or.inr` directly.
- `closed_not_diverge`: no closed well-typed expression has `Eval e .diverge`.

The base-type assumption `t = .int ∨ t = .bool` is the constructive translation
of membership in Isabelle's two-element set `{IntT, BoolT}`.

## Logical relation and fuel

`Reducible` is defined by recursion on the simple type. At either base type it
is ordinary value typing. At an arrow type it includes value typing and a
closure whose body terminates on every reducible argument, returning a
reducible result. `ReducibleEnv` relates association lists entry by entry,
including repeated names and their original first-binding shadowing behavior.

The fundamental theorem is an induction on the expression's typing derivation:

1. Variables use reducible environment lookup; constants terminate immediately.
2. A lambda captures its environment. Its body's induction hypothesis proves
   the closure's termination property for every reducible argument.
3. For application, the function, argument, and closure body each have a
   successful fuel budget. `STLC.interp_result_stable` raises all three to
   `max k₁ (max k₂ k₃)`. One additional unit evaluates the application.
4. The primitives are total at their assigned types: `succ` and `pred` operate
   on naturals (predecessor saturates at zero), and `isZero` returns a Boolean.
5. A conditional evaluates its reducible Boolean guard and the selected
   branch, using the maximum of their two budgets plus one.

This accounts for the source interpreter's depth-bounded fuel: recursive
calls share the predecessor budget rather than consuming a sequential counter.
Both value and constant info fields, closure captures, natural arithmetic,
argument evaluation order, and branch selection remain those of `STLC.lean`.

## Scope and logical strength

The source's `Lam` binds only its parameter. It has no recursive function name,
fixpoint operator, or recursive type. This proof establishes termination of its
specified call-by-value interpreter; it does not separately define and prove
strong normalization for every possible syntactic reduction strategy.

The recursively defined language in `Formal/Recursive.lean` is a different
language. Likewise, the logical cost of a universal return-or-diverge split
for arbitrary partial computations in `Formal/Observation.lean` does not imply
that this particular STLC theorem has that cost. A constructive proof of
termination resolves the STLC disjunction without such a general principle.

The module uses Lean and `Std` only, with no proof holes, added axioms,
classical reasoning, or native decision procedure. Its final `#print axioms`
commands report **no axioms** for all four principal theorems: no `propext`,
`Quot.sound`, `Classical.choice`, or `sorryAx`. Direct equality reasoning and
decidable comparisons prove the auxiliary fuel bounds without relying on
extensionality lemmas.

The module has been checked on both the project's pinned Lean 4.29.1 and Lean
4.35.0, with the same empty axiom reports. Run
`lake build Formal.Normalization` from `formal/`. Lean 4.35.0 emits deprecation
warnings for the `if_pos`/`if_neg` names retained for Lean 4.29.1 compatibility.
