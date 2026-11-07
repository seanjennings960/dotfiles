# Nix evaluation and multi-user deployment

Two executable, constructive Lean models connect Nix's composition language to
the deployment problems in Dolstra's thesis. Their guarantees are different:

* [`Formal/Nix.lean`](Formal/Nix.lean) proves interpreter/operational-semantics
  correspondence for a delimited call-by-name language with deferred substitutions.
* [`Formal/Deployment.lean`](Formal/Deployment.lean) proves preservation of
  immutable-store, dependency-closure, generation, and per-user-profile invariants.
* [`examples/deployment-check.py`](examples/deployment-check.py) exercises real Nix
  evaluation and derivation plans. With `--native`, it builds runnable artifacts,
  activates and rolls back native profiles, and checks GC in a disposable store.

Both Lean modules import only `Std`. There are no project axioms, `sorry`,
`Classical`, `native_decide`, or native proof shortcuts. The exhaustive declaration
audit permits Lean's constructive foundations `propext` and `Quot.sound` and rejects
all other axiom dependencies, including choice and `sorryAx`.

## Run

From a shell with this project's pinned Lean 4.29.1 and Nix available:

```sh
cd formal
lake build Formal.Nix Formal.Deployment
lake env lean examples/DeploymentAudit.lean
lake env lean --run examples/DeploymentChecks.lean
python3 examples/deployment-check.py --native
```

The repository's `formal/shell.nix` supplies the Lean toolchain. The Python runner
finds Nix on `PATH`, or in `/nix/var/nix/profiles/default/bin`; `FORMAL_NIX` and
`FORMAL_NIX_INSTANTIATE` can select explicit binaries; the native phase also accepts
`FORMAL_NIX_STORE` and `FORMAL_NIX_ENV`.
The distinct prefix avoids collision with nix-shell's standard `NIX_STORE`
directory variable. The runner uses Python's standard library.
Each process has a 30-second wall-clock limit, separate from Lean's semantic fuel.
Omit `--native` to run only the evaluation and derivation-plan checks.

## Reading Dolstra Chapter 1 accurately

Source: Eelco Dolstra, *The Purely Functional Software Deployment Model* (2006),
[thesis PDF](https://edolstra.github.io/pubs/phd-thesis.pdf). Page numbers below
are the **printed thesis pages**; PDF pages are eight higher.

| Chapter 1 passage | What it motivates here |
| --- | --- |
| §1.1, p. 3: correct deployment means the same behavior for identical inputs on developer and end-user machines | This is the broad engineering objective, stronger than either local theorem below. |
| §1.1, pp. 4–5: identify and realize environmental requirements; build-time and runtime dependencies can differ; compatible versions, configuration, and locating components matter | Explicit artifact dependency edges and closure. The model assumes those edges are complete. |
| §1.1, pp. 5–6: safe removal, avoiding interference, and remembering/reproducing old configurations | Retained generations are roots; rollback chooses retained history; GC preserves reachable objects. |
| §1.2, pp. 8–9: nominal dependencies and globally shared filenames obstruct side-by-side versions and independent users | Immutable identifiers, shared dependencies, distinct per-user profiles. |
| §1.2, pp. 9–10: destructive upgrading creates a window mixing old and new files | Build and stage first; activation replaces a complete profile selection in one transition. |
| §1.3, pp. 13–14: summarizes missing dependencies, interference, rollback, atomicity, and administrator-only deployment | These become explicit model invariants and API boundaries. |
| §1.4, p. 14: components live in an isolated central store, with names incorporating hashes of build inputs | Our abstract object identifiers represent such identities; hashing is an implementation assumption. |
| §1.5, pp. 14–15: the purely functional deployment model, shared components between independent users, atomic upgrades, O(1) rollback, GC, and a lazy pure composition language | This explains why the evaluator and store models belong in the same study. It does not identify their theorems. |
| §1.5, p. 15: service deployment also includes mutable state | Profile rollback here selects old immutable artifacts; it does not reverse databases or running-service state. |
| §1.6, p. 16: language semantics belongs to Chapter 4; store models to Chapters 5–6, with secure multi-user sharing an important distinction between them | Chapter 1 states the architecture and goals. It is not itself a store correctness proof. |

Thus the connection is: lazy pure expressions describe **which composition** is
wanted; realization produces its immutable store objects; profiles select those
objects for particular users. A language-evaluation theorem establishes the first
layer's specified behavior, not the correctness of builders, the store daemon,
filesystem operations, or deployment on arbitrary machines.

## NixLang: the operational details that matter

Rutger Broekhoff and Robbert Krebbers, “Verified Interpreters for Dynamic Languages
with Applications to the Nix Expression Language,” ICFP 2025, PACMPL 9, article
268, [DOI 10.1145/3747537](https://doi.org/10.1145/3747537),
[author PDF](https://robbertkrebbers.nl/research/articles/nix.pdf).
The corresponding [v3 artifact, DOI 10.5281/zenodo.15839106](https://doi.org/10.5281/zenodo.15839106)
contains the full Rocq development and OCaml frontend. Particularly relevant are
`theories/nix/operational.v`, `interp.v`, and `interp_proofs.v`. This Lean model is
a separate small development inspired by those definitions, not a translation or
certification of the complete artifact.

### Deferred substitution and binding priority

Paper §4.2, pp. 268:15–16, and Fig. 4:

```text
variable = name × Option (Kind × Expr)
Kind     = abs | with

merge(new with e, old abs d) = old abs d
merge(new binding, old)     = new binding
merge(no new binding, old)  = old
```

`Expr.var`, `merge`, and `subst` implement this representation directly. A variable
in a source expression initially has no saved binding. Substitution updates that
annotation; it **never recursively substitutes inside the saved replacement**.
When demanded, the `Step.deferred` rule evaluates the saved expression.

Substitution descends under `lam x body` **without removing `x` from the
substitution**. This is intentional. Beta reduction installs a fresh `abs`
binding, which overrides any prior annotation for `x`. For example:

```nix
let x = 7; in (x: x) 42                         # 42
let x = 7; in with { x = 99; }; x               # 7
let x = 7; y = x; in let x = 99; in y           # 7
```

The last example depends on keeping saved substitutions opaque. The checked
lemmas are `with_cannot_override_abs`, `new_abs_overrides`,
`saved_replacement_is_opaque`, `lambda_subst_descends`, and
`beta_rebinds_even_saved`.

`Expr.scope kind source body` implements the paper's unified `let/k` operation:
first shallow-evaluate `source` to attributes, then substitute its fields into
`body` using the specified tag. `letOne` is the **non-recursive singleton/sequential
core form**; nesting it gives sequential bindings. Real Nix's multi-binding `let`
is recursive. Full NixLang models that using recursive attributes and indirections
(§4.2, pp. 268:14–16); those constructs are outside this Lean fragment.

### Laziness, shallow/deep evaluation, and faults

Beta reduction substitutes the argument expression without evaluating it. This is
call-by-name: `(unused: 42) Omega` returns 42. There is no memoizing heap. Actual
Nix uses sharing/call-by-need; paper §1, p. 268:5 and §5, p. 268:21 explain the
consequences, including cyclic structures that real `deepSeq` can handle by
pointer-based cycle detection.

`Mode.shallow` exposes an attribute set without evaluating fields. `Mode.deep`
recursively evaluates its fields; lambdas remain values in both modes. `seq force
first second` forces `first` in the indicated mode, then evaluates `second` in the
surrounding mode. Compare:

```nix
builtins.seq     { nested = throw "forced"; } true  # true
builtins.deepSeq { nested = throw "forced"; } true  # error
```

`compareValues` first calls `sameDomain`; only matching domains produce
`compareFields`. The general lemma `unequal_domains_skip_values` states this
without assumptions on the field expressions. The examples include equal-sized,
different-domain sets with a common divergent field. See Fig. 5,
`binop-eq-attr`, p. 268:15.

Three compatibility boundaries are executable:

* **Unused `with` source:** the paper always shallow-evaluates it. Actual Nix can
  evaluate `with Omega; true` to `true`; this fragment times out at the tested
  fuel bound. Paper §5, p. 268:21 explicitly reports this discrepancy.
* **Function equality:** `Examples.functionComparison` proves that comparing
  two identity lambdas faults with `functionEquality` in this model, matching
  the artifact's `sem_eq` restriction. Native Nix evaluates `(x: x) == (x: x)`
  to `false`; the native fixture reports this separately. Function-comparison
  behavior is therefore another explicit boundary of model/native agreement.
* **Attribute comparison order:** the paper specifies whole-domain comparison
  before values, with a fixed ordering for value comparisons. In tested real Nix,
  `tryEval ({ a = bad; b = 1; } == { a = bad; c = 2; })` returned a caught error
  in an isolated expression, but returned successful `false` when embedded in
  the larger fixture. Attribute-name ordering can depend on surrounding code;
  the runner reports both observations instead of asserting agreement. Paper
  §4.1, p. 268:13 already emphasizes order-sensitive evaluation; its formal
  whole-domain rule is stated in Fig. 5. These observations are not a claimed
  proof of a particular real-Nix iteration algorithm.

### Exact scope and theorem statements

The Lean fragment includes booleans, nonnegative numeric literals, variables,
single-argument lambdas/application, nonrecursive attributes, tagged scopes,
static selection, conditionals, equality, and shallow/deep sequencing. Attribute
fields use association lists. For the intended Nix-like source subset, names
are distinct and lists are in a consistent fixed name order; the raw machine is
also defined on other lists, whose behavior is simply its association-list
semantics. Numeric literals are represented by `Nat`; matching the paper's
integer subset additionally requires literals below 2^63. There is no arithmetic.

Recursive attributes, matching lambdas/defaults, lists, floats, strings, paths,
derivations, I/O, dynamic attribute names, `__functor`, and the Nix parser are
outside this fragment. Recursive defaults and lists are exercised by the **real
Nix fixtures**, not claimed as Lean language features. The full paper itself
excludes filesystem/package-manager features such as paths and derivations
(§1, p. 268:5).

`Step` is an inductive small-step continuation-machine semantics with separate
constructors for beta reduction, variable forcing, traversal, and errors. It is
not defined by the equation `tick s = more t`. `tick` independently implements
one instruction; `run` iterates it with fuel. This is a machine interpreter, not
the paper's full environment/thunk interpreter or a proven refinement of it.

Main APIs in namespace `Formal.Nix`:

| API/theorem | Guarantee |
| --- | --- |
| `eval fuel mode expr` | Executable entry point. |
| `tick_step_iff` | Executable one-step behavior iff the independently defined `Step`. |
| `step_deterministic` | Two steps from the same machine state have the same successor. |
| `interpreter_correspondence` | Some fuel returns answer `a` iff a finite `Steps` path reaches a state satisfying `Halt _ a`; covers both values and faults. |
| `more_fuel_same_answer` | Additional fuel cannot change a completed answer. |
| `timeout_prefix` | A timeout stores the actual state reached after exactly that many steps. |
| `divergence_correspondence` | All fuel bounds time out iff every finitely reachable state has a further step. |
| `fault_is_terminal` | A genuine fault state has no semantic successor. |

`Result.done (Answer.fault f)` differs from `Result.timeout state`. Zero fuel can
even time out on a terminal state, because observing termination costs one tick.
A **single** timeout proves only a finite prefix. The checked `Omega` examples
test finite timeouts; the general divergence theorem quantifies over **all** fuel
bounds. It is analogous in shape to the paper's Theorem 4.1 (§4.4, p. 268:20), but
applies only to this machine and fragment.

## Separate deployment transition system

The `Formal.Deployment` state contains:

* a shared store mapping object identifiers to immutable `Artifact` records
  (`dependencies`, `content`);
* an arbitrary number of users, each with a `Profile`: next generation serial,
  retained generations, active generation, and optional staged roots.

`Invariant` requires store dependency closure, present roots for every retained
and staged generation, an active generation belonging to retained history,
unique generation serials, and serials below the next counter.

| Operation | Preconditions and effect |
| --- | --- |
| `build` | Fresh identifier and already-present dependencies; publish one completed object, preserving every existing record. This models the successful completion of a build. |
| `stage` | All selected roots exist; record them without changing the active profile. |
| `activate` | A staged selection exists; atomically install one complete new generation, retain the old history, clear staging, increment the counter. |
| `rollback` | Target generation is retained; replace the active selection with that generation. |
| `forget` | Filter history by serial, always preserving the active generation. |
| `collect` | Keep every retained/staged root and keep dependencies of kept objects; remove other objects without changing profiles. Keeping extra garbage is allowed. |

`execute` checks ordinary command preconditions and returns `Except Error State`.
Invalid operations return an error rather than a modified state. `executeFor`
takes an external principal and a `Request` containing no other-user field;
`executeFor_other_user` proves that every successful request preserves all other
profiles exactly. `Command`/`executeAll` are also exposed as a lower-level
administrative scenario interface.

General checked proofs include:

* `transition_invariant`, `trace_invariant`, `execute_preserves`,
  `executeFor_preserves`, `executeAll_preserves`;
* `build_preserves_existing`, `stage_does_not_activate`, `build_does_not_activate`;
* `activation_complete`, `rollback_restores`, `active_closure_present`;
* `executeFor_other_user` and the individual `*_other_user` lemmas;
* `gc_keeps_closure`, `gc_preserves_reachable`, `gc_preserves_profiles`.

The GC API is **certified rather than a tracing implementation**: its caller
supplies a Boolean keep predicate and proofs of `KeepsRoots` and
`KeepsDependencies`. `Reachable` describes arbitrary transitive dependency paths.
Theorems establish that GC preserves the exact artifact record at every reachable
identifier, not just that profile pointers themselves remain unchanged.

### Executed multi-user scenario

`Examples.commands` builds a shared runtime (10), Alice's editor versions (11,
12), Bob's tool (13), and an unused output (99). Alice and Bob independently
activate generation 0. Alice upgrades to generation 1, rolls back to 0, and
forgets generation 1. Bob stages object 12 without activating it. GC then:

* keeps 10, 11, and 13 for the two active generations;
* keeps 12 **only because Bob has staged it**, despite Alice having dropped it;
* removes 99;
* leaves Alice active at `{serial = 0, roots = [11]}` and Bob active at
  `{serial = 0, roots = [13]}`, with `[12]` staged for Bob.

`configured_invariant` follows from the general command interpreter theorem;
`collected_invariant` follows from the general GC theorem and proved concrete
root/dependency retention. The examples also check rejection of overwriting
object 10, staging missing object 404, and rolling back to forgotten generation 1.

### Engineering assumptions

Atomic publication/activation are primitives of the transition system. Refining
them to durable filesystem operations, crash recovery, and concurrent readers
requires further work. No complexity theorem establishes the thesis's O(1)
rollback claim. This model uses a functional list for history lookup.

Object identifiers abstract correct immutable identities. The model assumes
complete dependency metadata and trustworthy completed artifacts; it does not
prove collision resistance, hermetic builds, source/binary equivalence, or
application-level behavior. Authentication supplies `executeFor`'s principal;
OS ownership and daemon enforcement are outside Lean. Histories and staging are
the modeled roots; real systems may also need process roots, indirect roots,
leases, and build-in-progress roots. Serialized transitions express safety of
interleavings, not a concurrent-GC protocol. These are deployment assumptions,
not consequences of the NixLang theorem.

## Real Nix evidence, builds, and native profiles

`nix-semantics.nix` has 26 asserted checks: absolute/weak scoping, lambda
rebinding, saved closures, lazy arguments/attributes, recursive `let`/attributes,
inherited bindings, mutually referential defaults, recursive function defaults,
`seq`/`deepSeq` over attributes and lists, equality, lazy `with`, and shared cycles.
The runner additionally checks five expected evaluator failures, including
infinite-recursion detection, and reports both domain-order observations.

`deployment-plan.nix` creates four real derivations: one shared runtime, two
Alice versions, and Bob's tool. String contexts on referenced output paths carry
the runtime dependency into each application's `inputDrvs`/`inputs.drvs`.
The runner checks distinct output identities, per-user desired selections, and
the three shared dependency edges by inspecting `nix derivation show` JSON.
Each application has `bin/run`, which prints its identity and reads the shared
runtime's message via its immutable store path.

### Native deployment demo (`--native`)

The additional native phase runs the following checked sequence:

1. Build all four derivations with `nix-store --realise`; verify each application's
   exact store closure is itself plus the shared runtime.
2. Set separate temporary Alice/Bob profiles with `nix-env --profile ... --set`;
   run both applications through their profile links.
3. Attempt a deliberately failing build (exit 23); verify Alice's active
   application still runs unchanged.
4. Activate Alice v2, verify Bob's link/output are unchanged, use native
   `nix-env --rollback`, and run Alice v1 again.
5. Run GC and verify inactive but retained Alice v2 survives.
6. Register v2 as Bob's staged indirect GC root, delete Alice's generation 2,
   build an unreferenced output, and run GC. The staged output survives while
   the unreferenced output is deleted.
7. Remove Bob's staged root and collect again. v2 disappears; Alice v1, Bob's
   application, and the unchanged shared-runtime bytes survive and still run.

The two profiles are **named users simulated under the invoking OS account**;
this does not exercise OS account authentication. Native generation numbers
start at 1, whereas the Lean model starts at 0. Native profile management is
performed by Nix, rather than a Python emulation of profile links. The checks
observe states after each operation; the Lean model's one-step activation
theorem is not a verification of Nix's concurrent filesystem implementation.

Evaluation/plan checks use a temporary `local?root=...` store. The native phase
uses `local?store=...&state=...&log=...` with all three paths under another
temporary directory. A non-diverted logical store is important because macOS
does not support builds in Nix's Linux-style chroot store. Its database, logs,
build directories, `HOME`, configuration directories, profiles, and GC roots
are isolated and removed on exit. Every native command is passed this store;
output paths are checked against its store directory before deployment/GC.

The example's `/bin/sh`, `/bin/mkdir`, `/bin/cat`, and `/bin/chmod` are explicit
host-tool parameters. Sandbox isolation is disabled only for these tiny
trusted native-demo builders. Host tools and runtime shell utilities are ambient
platform prerequisites, not store-closure members: this example does not claim
hermeticity or complete accounting of the host OS. No nixpkgs fetch or network
dependency is needed; substituters and remote builders are disabled. No real
user/system profile is selected and no real-store garbage collection occurs.

Checked locally with Lean 4.29.1; the complete `--native` runner (evaluation,
plans, builds, profiles, and GC) passes on macOS with both Nix 2.34.9+1 and Nix
2.35.4. `DeploymentChecks.lean` runs the Lean examples and prints
axiom dependencies of principal theorems; `DeploymentAudit.lean` checks **every**
imported declaration in both model modules. The current combined audit is
recorded in [CHECKS.md](CHECKS.md); only `propext` and `Quot.sound` are used.
