# STLC translation

`Formal/STLC.lean` translates `/Users/sean/Downloads/EvalSTLC.thy` directly,
using only `import Std` and namespace `STLC`. It includes the source syntax,
interpreter, observation relation, typing judgments, and constructive
finite-fuel safety proofs. All proof terms are checked by Lean's kernel.

Input SHA-256:
`21645ca95604799eb56392bf5a8f98eea49fd2ca0ab864e93076671ed69dbc76`.
The independently checked Isabelle compatibility copy and the original
legacy-script failure are documented in [TOOLS.md](TOOLS.md#isabelle-input).

## Source correspondence

Names in this table are relative to `STLC`.

| Isabelle source | Lean translation |
| --- | --- |
| `'a result`; `Result`, `Stuck`, `TimeOut` | `Result α`; `.result`, `.stuck`, `.timeout` |
| `result_bind`, `return`, `stuck`, `timeout` | `result_bind`, `«return»`, `stuck`, `timeout` |
| `info`, `name` | `Info`, `Name` (both `Nat`) |
| `ty`; `IntT`, `BoolT`, `ArrowT` | `Ty`; `.int`, `.bool`, `.arrow` |
| `const`; `IntC`, `BoolC` | `Const`; `.int`, `.bool` |
| `prim_op`; `Succ`, `Pred`, `IsZero` | `PrimOp`; `.succ`, `.pred`, `.isZero` |
| `expr`; `Var`, `Const`, `Lam`, `App`, `PrimApp`, `IfE` | `Expr`; `.var`, `.const`, `.lam`, `.app`, `.primApp`, `.ifE` |
| `val`; `VConst`, `Closure` | `Val`; `.const`, `.closure` |
| `env`, `tyenv` | `Env = List (Name × Val)`, `TyEnv = List (Name × Ty)` |
| `lookup`, `to_int`, `to_bool`, `to_closure` | Same names |
| `from_int`, `from_bool`, `delta`, `interp` | Same names and argument order |
| `observable`; `OConst`, `ODiverge` | `Observable`; `.const`, `.diverge` |
| `eval`; `evalc`, `evald` | `Eval`; `.evalc`, `.evald` |
| `typeof`, `typeof_op` | Same names |
| `wt_expr`; `TVar`, `TConst`, `TLam`, `TPrimApp`, `TApp`, `TIf` | `WtExpr`; `.var`, `.const`, `.lam`, `.primApp`, `.app`, `.ifE` |
| Mutually inductive `wt_value`, `wt_env` | Mutually inductive `WtValue`, `WtEnv` |
| `TVConst`, `TClos` | `WtValue.const`, `WtValue.closure` |
| `WTEmEnv`, `WTConsEnv` | `WtEnv.nil`, `WtEnv.cons` |
| `wt_result`; `wtresult`, `wttimeout` | `WtResult`; `.result`, `.timeout` |
| `wtvar_inv`, `wtconst_inv`, `wtlam_inv`, `wtapp_inv`, `wtprimapp_inv`, `wtif_inv` | Constructor inversion by `cases` on `WtExpr`; Lean generates its eliminator |
| `bool_val`, `int_val`, `fun_val` | Explicit canonical-form lemmas `bool_value`, `int_value`, `fun_value` |
| `wtres_inv` | Constructor inversion by `cases` on `WtResult` |
| `typeof_bool`, `typeof_fun` | Same names, including their elimination-style conclusions |
| `delta_safe`, `lookup_safe`, `interp_safe` | Same names and mathematical statements |
| `type_safety` | `STLC.Normalization.type_safety` in `Formal/Normalization.lean`, constructively proved using termination |

Source simplification declarations and custom Isabelle syntax become ordinary
definitions and explicit Lean constructor proofs. `wt_bind` factors out the
source's repeated inversion on well-typed results.

## Semantic details

- Every source `info` field is preserved, including the distinct outer and
  inner fields in `Expr.const` and `Val.const`. Primitive results use the
  primitive operator's info for both fields, exactly as in the source.
- Despite the `Int` names, constants contain **natural numbers**. Subtraction
  is saturating, so predecessor of zero is zero. `isZero` computes Boolean
  natural-number equality.
- Lambdas are **nonrecursive**. They capture the current association list;
  application extends that captured environment only with the argument.
- Environments are lists with first-match lookup, allowing shadowing and
  duplicate names. `WtEnv` relates entries in matching list order.
- Fuel bounds recursion depth, not a shared instruction budget. Fuel zero
  always times out; every recursive call uses the same predecessor fuel.
- Application first evaluates the operator, then the argument, then checks
  whether the operator is a closure, then evaluates its body. Thus an
  argument timeout takes precedence over detecting a nonfunction operator.
- Conditionals check the Boolean condition and evaluate only its selected
  branch. Binding propagates stuck and timeout separately.
- The source `Eval` relation observes constants (including their inner info)
  and universal timeout. It does not observe closures or stuck outcomes.

## Safety API

```lean
delta_safe  (hop : typeof_op f = .arrow a b) (hv : WtValue v a)
  : WtResult (delta f v) b

lookup_safe (hρ : WtEnv Γ ρ) (hl : lookup Γ x = .result a)
  : WtResult (lookup ρ x) a

interp_safe (he : WtExpr Γ e a) (hρ : WtEnv Γ ρ) (k : Nat)
  : WtResult (interp e ρ k) a

no_stuck (he : WtExpr Γ e a) (hρ : WtEnv Γ ρ) (k : Nat)
  : interp e ρ k ≠ .stuck

closed_no_stuck (he : WtExpr [] e a) (k : Nat)
  : interp e [] k ≠ .stuck
```

`interp_safe` is induction on fuel. It uses canonical forms to expose typed
closures and Booleans, and `WtEnv.cons` to type closure-body environments.
Timeout is permitted by `WtResult`; stuck has no typing constructor.

### Constructive fuel coherence

`Result.Refines r s` means `r = .timeout ∨ r = s`: increasing fuel may
resolve a timeout, but cannot alter a settled result.

```lean
interp_mono e ρ (hkl : k ≤ l)
  : Result.Refines (interp e ρ k) (interp e ρ l)

interp_stable (hkl : k ≤ l) (h : interp e ρ k ≠ .timeout)
  : interp e ρ l = interp e ρ k

interp_result_stable (hkl : k ≤ l) (h : interp e ρ k = .result v)
  : interp e ρ l = .result v

interp_stuck_stable (hkl : k ≤ l) (h : interp e ρ k = .stuck)
  : interp e ρ l = .stuck

interp_coherent (hk : interp e ρ k ≠ .timeout)
    (hl : interp e ρ l ≠ .timeout)
  : interp e ρ k = interp e ρ l
```

These statements require no typing assumption. `interp_mono` follows from
fuel induction and `result_bind_mono`; `interp_coherent` uses constructive
comparison of the two natural fuel bounds.

### Unbounded observations

The source's final `type_safety` states a disjunction between universal
timeout and eventual constant observation for closed base-typed expressions.
Its given proof splits on `∀ k, interp e [] k = TimeOut`, then obtains a
counterexample fuel from the negation. That step is classical. The exact
source observation relation is retained as `Eval`, while the proofs here
provide finite-fuel safety and coherent finite observations constructively.
They do not by themselves decide the source's unbounded disjunction.
The separate [logical-relations proof](NORMALIZATION.md) constructs a
terminating fuel for every closed well-typed term in this nonrecursive
language, and hence proves the exact source disjunction constructively.

There are no `classical`, `sorry`, `axiom`, or `native_decide` proof steps.
On the pinned Nix Lean 4.29.1, `#print axioms` reports **no axioms at all** for the three
source safety lemmas, `no_stuck`, and the monotonicity/stability/coherence
lemmas, including no dependency on propositional extensionality or choice.

## Executable examples

From `formal/`:

```sh
lean Formal/STLC.lean
```

The file contains kernel-checked computation examples for typed application,
information fields, natural predecessor, shadowing, environment capture,
selected-branch evaluation, and argument-before-closure-check order. Its four
`#eval` commands print, respectively:

```text
STLC.Result.result (STLC.Val.const 31 (STLC.Const.int 31 42))
STLC.Result.result (STLC.Val.const 2 (STLC.Const.int 2 0))
STLC.Result.timeout
STLC.Result.stuck
```
