# The blog's recursive language

[`Formal/Recursive.lean`](Formal/Recursive.lean) formalizes the language in
Jeremy Siek's [Type Safety in Three Easy Lemmas][blog]. Everything is in
`namespace Recursive`, with only `import Std`. This is a separate development
from the translation of the supplied nonrecursive STLC.

## Correspondence with the blog

| Blog | Lean |
| --- | --- |
| `Int`, `Bool`, function types | `Ty.int`, `Ty.bool`, `Ty.fn` |
| Integer/Boolean constants | `Const.int : Int → Const`, `Const.bool` |
| `+`, `-`, integer equality | `Op.add`, `Op.sub`, `Op.eq`; `Delta`, `delta` |
| `fun f(x:T) body` | `Expr.fn f x T body` |
| Application | `Expr.app` |
| Association-list lookup | `lookup`, with first matching name winning |
| Value, stuck, timeout | `Result.value`, `Result.stuck`, `Result.timeout` |
| Fuel-indexed evaluation | `interp k ρ e` |
| Expression/value/result/environment typing | `HasType`, `ValueTyped`, `ResultTyped`, `EnvTyped` |

The syntax has exactly constants, binary operators, variables, named recursive
functions, and applications. There is no conditional extension. Equality accepts
two integers and returns a Boolean. Integer arithmetic uses Lean's unbounded
`Int`, including negative results from subtraction.

Fuel zero always returns timeout. At positive fuel, both operands and an
application's body receive the same predecessor fuel, just as in the blog:
this is a depth bound, not a globally consumed step budget. Application evaluates
the function expression, then the argument, then checks that the first value is
a closure.

Applying the closure `v = Value.closure f x A body captured` to `w` evaluates
its body in

```lean
(x, w) :: (f, v) :: captured
```

Thus the argument shadows self when `x = f`, and both new bindings shadow the
captured environment. A closure contains **only the old environment**. Its self
binding is added on application, so ordinary finite inductive values suffice;
no cyclic value or coinductive closure is assumed. The typing rule uses exactly
the same binding order. Function argument annotations are retained in closures.

## Checked safety proofs

The three lemmas have the blog's strength:

- `delta_safe`: well-typed operands and a successful `Delta` judgment give an
  actual returned value of the declared result type.
- `lookup_safe`: a successful context lookup in a well-typed environment gives
  an actual returned value of that type.
- `interp_safe`: `HasType Γ e A → EnvTyped Γ ρ →`
  `ResultTyped (interp k ρ e) A` for every fuel `k`.

The last proof is induction on fuel. It accounts for intermediate timeouts using
`bind_safe`, rather than assuming that the two recursive evaluations return
values. In the application case, closure typing supplies the captured context
and body derivation; the body environment is built from the typed argument,
the same typed closure as self, and the typed captured environment.

`no_stuck` rules out `Result.stuck` at every fuel. These statements allow arbitrary
well-typed open environments; closed programs instantiate both environments
with `[]` and use `EnvTyped.nil`.

## Fuel stability and constructive observations

`interp_stable` states:

```lean
k ≤ l → interp k ρ e ≠ Result.timeout → interp l ρ e = interp k ρ e
```

It applies to **every expression and environment**, including untyped ones and
stuck results. `interp_step` proves its one-step form using `Result.Refines`;
stability is then induction on the fuel inequality. Timeout makes no assertion
about later observations.

The whole-program observations are explicit propositions:

```lean
Returns ρ e v := ∃ k, interp k ρ e = Result.value v
Diverges ρ e  := ∀ k, interp k ρ e = Result.timeout
GoesWrong ρ e := ∃ k, interp k ρ e = Result.stuck
```

- `returns_unique`: two witnessed returns have equal values, by comparing their
  observations at the maximum of the two fuels.
- `returns_typed`: every witnessed return from a well-typed program is typed.
- `returns_int`, `returns_bool`: at base type, that return is an integer or
  Boolean constant, respectively.
- `never_goes_wrong`: well-typed programs have no stuck observation.
- `diverges_iff_no_return`: for a well-typed program, all fuels time out iff
  no value has a witnessed return.

These facts do not require choosing between eventual return and divergence.
In particular, the last equivalence does not eliminate a double negation to
extract a terminating fuel. It is a constructive characterization, not an
algorithm deciding termination.

## Examples and checking

- `arithmetic` computes `(40 + 3 - 1) = 42`; `arithmetic_typed` and
  `arithmetic_returns` prove Boolean typing and return of `true` at fuel 4.
- `shadowing` is `(fun f(f:Int). f) 7`; `shadowing_typed` and
  `shadowing_returns` check that the argument precedes the self binding and
  yields `7` at fuel 2.
- `loop` is `(fun f(x:Int). f x) 0`. `loop_typed` gives type `Int`.
  `loopBody_timeout` is induction on **arbitrary** fuel in the active body
  environment, and `loop_timeout` lifts that fact to the closed application.
  `loop_diverges : Diverges [] loop` consequently proves genuine divergence,
  rather than checking a finite collection of timeouts.

From `formal/`, run `lean Formal/Recursive.lean` in the configured toolchain.
The file has been checked with Lean 4.29.1 (the pinned Nix toolchain) and 4.35.0.
It contains no `classical`, `sorry`, `axiom` declaration, or `native_decide`.
Auditing the safety, stability, observation, and example theorems with
`#print axioms` reports only Lean's foundational `propext` and, for some proofs,
`Quot.sound`; there is no `Classical.choice` or `sorryAx` dependency.

[blog]: https://siek.blogspot.com/2013/05/type-safety-in-three-easy-lemmas.html
