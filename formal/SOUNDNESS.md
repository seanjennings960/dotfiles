# Constructive soundness: what replaces the last case split?

Siek's [2013 post](https://siek.blogspot.com/2013/05/type-safety-in-three-easy-lemmas.html)
defines a total interpreter with three results: value, stuck, and timeout.
Its three lemmas establish:

1. Typed primitive arguments produce a typed value.
2. A typed environment supplies a typed value for a typed variable.
3. Every finite-fuel interpretation of a typed expression returns either a
   typed value or timeout, never stuck.

The primitive/application cases in the prose skip intermediate timeouts:
the induction hypothesis does **not** guarantee a value. The Lean proofs
explicitly propagate timeout and exclude stuck by inversion of result typing.

## The logical gap

The last paragraph of the post asks whether

```
∀ k, interp e [] k = timeout
```

and, in the negative branch, extracts a counterexample fuel. Neither step is
available for arbitrary computations in constructive logic. A fuel bound is
decidable; the unbounded question is a different proposition.

`Formal/Observation.lean` makes this precise without classical axioms. A
partial computation is a coherent family of finite observations:

```lean
structure Partial (α : Type) where
  observe : Nat → Option α
  stable : ∀ {n m a}, n ≤ m → observe n = some a → observe m = some a
```

`none` means **pending at this budget**. It does not assert divergence.
The index is recursion-depth fuel, not elapsed time or a count of machine
instructions: sequential subcalls can use the same smaller bound.

Define `Returns p a := ∃ n, p.observe n = some a` and
`Diverges p := ∀ n, p.observe n = none`. Coherence proves uniqueness of
returned values. Constructively,

```
Diverges p ↔ ¬ ∃ a, Returns p a
```

but this equivalence does not decide either case. `dichotomy_implies_lpo`
and `lpo_implies_dichotomy` prove that a global split for arbitrary such
computations is equivalent to limited omniscience:

```
∀ b : Nat → Bool, (∀ n, b n = false) ∨ (∃ n, b n = true).
```

The reduction searches successive finite prefixes of `b`. It is a theorem
about **arbitrary observation streams**, not a claimed encoding of every
mathematical stream as a finite source program. For a Turing-complete recursive
language the corresponding schema concerns halting excluded middle. We do not
prove an expressivity or unprovability theorem for the blog's abbreviated
grammar. Nor does this say that a particular terminating program cannot have
a constructive termination proof.

## A constructive evaluation definition

First retain errors faithfully:

```
timeout   ↦ none
stuck     ↦ some (Except.error ())
result v  ↦ some (Except.ok v)
```

Fuel stability makes this a `Partial (Except Unit Val)` for **every**
expression. Thus an ill-typed stuck program has a visible error observation;
it is not quietly reclassified as a divergent program.

For a well-typed program the third lemma says that every returned observation
is `Except.ok v` with `WtValue v T`. `Partial.values` then constructs

```
Partial {v : Val // WtValue v T}
```

and `Partial.values_observe` proves that forgetting the certificate and
reinserting `Except.ok` gives exactly the original observations. This is the
constructive soundness conclusion: a defined, executable partial value with
a type certificate at every returned observation. It requires no decision
about when, or whether, a value appears. The proof term is a function, not a
classical existential witness selected by choice.

`Formal/Soundness.lean` instantiates this definition for both interpreters.
`STLC.source_constant_iff`, both `source_divergence_iff` theorems, and
`Recursive.source_return_iff` prove agreement with the source observation
relations. Thus the constructive evaluation object preserves the meaning of
termination and divergence while avoiding a premature choice between them.

`Partial.map` and `Partial.bind` provide compositional operations; diagonal
fuel is sufficient because stability lets both stages run at a common larger
bound. This is an intensional presentation: different costs can give different
streams even when they eventually return the same value. No quotient by
running time is needed for safety.
`Partial.bind_returns` proves that a composite returns exactly when its first
stage returns an argument and its second stage returns the requested value.

## Two source languages, two termination claims

The supplied `EvalSTLC.thy` has natural-number constants (despite the name
`IntT`), unary successor/predecessor/zero-test, conditionals, and **nonrecursive**
lambda abstraction. The blog has binary arithmetic and **named recursive**
functions. Translating one is not a verification of the other.

The nonrecursive language admits a constructive logical-relations termination
proof. Consequently its original base-type conclusion can be proved by
constructing the terminating branch, without the Isabelle proof's classical
case split. The recursive language instead admits a well-typed infinite loop;
its general constructive conclusion is the typed partial computation above.
See `STLC.md`, `NORMALIZATION.md`, and `RECURSIVE.md` for the separate proofs.

## Why the examples use the same design

* **Editor:** an absent definition at an empty hole, a rejected edit, a pending
  request, and a stale response are different observations. A finite event
  transition preserves the editor invariant; it need not decide the future
  event stream. Hazelnut's action sensibility is preservation under editing,
  not a theorem that unfinished source programs evaluate successfully.
* **Deployment:** an unevaluated attribute, a failed evaluation/build, and a
  realized store path are different states. A configuration can be shallowly
  available while forcing a selected component diverges or faults. Profile
  activation has its own store-closure invariant, beyond language evaluation.

The common method is to define the computation and its observations first,
then prove that every finite step or returned observation satisfies the
appropriate invariant. No global success/failure/termination oracle is needed.

The word **soundness** has different conclusions here: Siek excludes runtime
type errors under typing assumptions; Hazelnut preserves typing under edit
actions; the NixLang paper relates an untyped interpreter to reduction,
including erroneous executions. A correct Nix interpreter must preserve
faults, not prove that all Nix configurations are fault-free.

For a future Nix-aware editor, the paper's `with g {}; x` example explains why
go-to-definition needs an explicit unknown/pending outcome: locating `x` can
depend on evaluating `g`. Hazelnut's lexical lambda bindings permit a structural
resolver; Nix's dynamic attributes additionally require evaluation evidence.
An LSP response contract specifies the shape and freshness of an answer, while
the language-specific resolution theorem supplies its semantic justification.

## Trust

The intended proof check is Lean's kernel, with an axiom audit of the project
declarations. Lean's propositional extensionality and quotient soundness are
constructively compatible infrastructure; `Classical.choice`, `sorryAx`,
native-evaluation axioms, and project-defined axioms are excluded. Concrete
examples use reduction or kernel-checked `decide`, not `native_decide`.
