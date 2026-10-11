# Executable creation policy in Lean

This prototype specifies the controller behind `dev` environment acquisition and
creation. It is an executable state machine with machine-checked proofs about
all of its reachable executions. The executable runs examples of that same
machine; it does not invoke Docker or download packages.

## Run it

Run these commands from `formal/`:

```sh
lake build
lake exe creation_model
lake exe creation_model trace
lake env lean Audit.lean
```

`lean-toolchain` pins Lean 4.23.0. Only Lean's bundled standard library is used;
there are no third-party package dependencies. Provision the toolchain before
running in an offline environment.

- `lake build` checks the general proofs and the concrete scenario expectations,
  then builds the executable. Warnings are errors.
- `lake exe creation_model` runs 17 scenarios and exits nonzero on failure.
- `trace` prints each input and emitted backend effect in the three-registry
  example, including an allowed redirect followed by offline creation.
- `Audit.lean` prints theorem dependencies. The proofs use Lean's standard
  logical axioms, with no added axioms, `sorry`, or `native_decide`.

## Agreed contracts

These are the decisions made for the first prototype:

| Question | Contract |
| --- | --- |
| Entry point | Managed operations enter through `dev`; direct Docker/devcontainer invocation is outside the model. |
| Offline | No network sockets during creation, including loopback and DNS. Files and local IPC are permitted. |
| Setup scripts | May attempt networking; the trusted backend must block it. |
| Acquisition | A separate explicit fetch command is the only source of network grants. |
| Version selection | Fetch requires a lock and cannot resolve or upgrade versions. |
| Registry support | OCI, APT, and PyPI, with multiple named registries per ecosystem. |
| Registry authority | A user-selected trusted profile enumerates allowed origins, including required artifact/authentication hosts. Every redirect is checked. |
| Reuse | Removing acquisition permission does not invalidate verified local content matching the lock. |
| Preflight | All declared inputs must be available before creation is authorized. |
| Input lifetime | The backend leases an immutable input snapshot throughout build and setup. |
| Partial fetch | Already published, verified artifacts survive failure. |
| Concurrency | One controller operation at a time; overlapping operations are rejected. |
| Completion | Backend confirmation covers all finite setup work. Background survivors stay network-blocked. |
| Failure | Retain verified inputs and report failure. Partial environments may remain blocked; there is no automatic retry, rollback, or fetch. |

## Lifecycle

```text
Idle --beginFetch(lock, grant)--> Fetching
  Fetching --request--> Downloading
  Downloading --redirected--> Downloading (new transfer ID; recheck origin)
  Downloading --received(matching digest)--> Publishing
  Publishing --published--> Fetching (artifact now available)
  Fetching --finishFetch(all inputs present)--> Idle / fetched

Idle --beginCreate(complete lock)--> Building --buildFinished--> SettingUp
  SettingUp --setupFinished--> Idle / created

Any active operation --backendFailed(quiescent)--> Idle / failed
```

Downloading and publishing are substates of `Fetching`. Only one transfer may
be pending. A download request emits a `download` effect; a matching digest emits
a `publish` effect. **The store changes only after publication acknowledgement.**
This prevents a successful download from being mistaken for durable availability.

Run IDs distinguish separate operations. Transfer IDs distinguish downloads and
redirect hops within an operation. Callbacks must match the active IDs and phase;
a delayed acknowledgement cannot publish the next download's artifact.

Creation emits `build(..., Network.none)` and then `setup(..., Network.none)`.
Freshness and Docker result-cache policy are not acquisition permissions. This
prototype models the input store; result-cache scheduling is left to the backend.

`step` returns either an accepted state/effect pair or an error. `applyInput`
defines rejection as unchanged state with no effects. `execute` runs arbitrary
finite sequences, including rejected commands and callbacks. For an actual I/O
failure the backend must cancel/drain outstanding work before sending
`backendFailed`; an ordinary policy rejection is not that acknowledgement.

## What is proved

The proofs are in `DevCreation/Proofs.lean`. They quantify over arbitrary states
satisfying the invariant and arbitrary inputs, rather than enumerating the
example workflows.

| Theorem | Guarantee |
| --- | --- |
| `execute_preserves_wellFormed` | Every finite execution preserves verified store entries, valid pending transfers, and complete creation input sets. |
| `reachable_effects_safe` | Every backend effect issued from a reachable state obeys its defined contract. |
| `download_has_explicit_grant` | Any emitted download after any finite history has an earlier explicit `beginFetch` authorizing its registry/origin and locked artifact. |
| `grant_only_from_beginFetch` | No other input can install or change the active grant or lock. |
| `creation_effects_have_no_network` | Both build and setup effects always carry `Network.none`. |
| `creation_never_downloads` | No accepted input during build or setup emits a download. |
| `creation_preserves_store` | The controller cannot mutate or evict inputs during creation. |
| `active_inputs_cannot_be_evicted` | Eviction is rejected throughout every active operation. |
| `no_overlapping_operations` | Starting another fetch or creation while busy is rejected. |
| `failure_preserves_store` | A backend failure retains already published inputs and emits no retry/fetch effects. |
| `rejection_is_noop` | Rejected inputs do not change state or emit effects. |

`WellFormed` ties the proofs together: stored receipts match locked digests,
pending downloads belong to the active lock and grant, pending publications have
matching measured digests, and building/setup states have complete valid inputs.
It holds initially and is preserved by the **actual executable `step` function**.

The scenario expectations in `DevCreation/Scenarios.lean` are also checked with
kernel evaluation (`by decide`). They demonstrate cold-cache rejection, partial
failure, grant revocation/local reuse, invalid redirects, wrong hashes, stale
callbacks, input eviction, platform changes, and the successful three-registry
workflow. These examples complement the general proofs.

## Trusted backend and representation boundary

The proof is conditional on these explicit contracts:

1. **Commands and profiles:** only an explicit user fetch command supplies a grant.
   A project's setup code cannot inject controller commands or replace profiles.
   The adapter canonicalizes origins and validates registry configuration.
2. **Downloads:** the backend performs only authorized requests. It pauses before
   following each redirect and requests authorization for the new origin. Digest
   observations refer to the actual bytes of the identified transfer.
3. **Publication:** `published(run, transfer)` means those verified bytes have
   been atomically placed in immutable storage. Partial files are unavailable.
4. **Build:** before executing any project code, `build` atomically rechecks and
   leases the complete manifest, or reports failure. The lease covers subsequent
   setup. No network sockets are available to build/setup code or descendants.
5. **Scope of isolation:** the network contract includes host initialization hooks,
   image/frontend resolution, Feature handling, and container lifecycle hooks.
   A Docker `RUN --network=none` flag alone does not implement this whole contract.
   OCI inputs must be consumed through local storage/IPC, not a local HTTP registry.
6. **Terminal callbacks:** completion/failure confirms that outstanding work has
   finished or been cancelled. Leases can then be released; partial environments
   and background survivors remain network-blocked.

`Digest` and `Origin` are opaque strings. A nonempty pinned identity is required,
but the prototype does not implement hashing, URL parsing, signature checks,
package resolution, or dependency-closure discovery. The manifest supplied by
the adapter is assumed to enumerate the needed inputs; missing undeclared inputs
must fail without network fallback. The example digests are deliberately fictional.

The store, run counters, and leases are modeled in memory. Crash recovery,
durable controller state, runtime network policy after creation, and concurrent
controllers require additional contracts. The current Python `dev` CLI is not
yet connected to this model, so these theorems are not claims about its present
Docker behavior.

## Layout

- `DevCreation/Model.lean`: data types and executable transitions.
- `DevCreation/Proofs.lean`: invariants, transition proofs, and history induction.
- `DevCreation/Scenarios.lean`: concrete scenarios and checked expectations.
- `Main.lean`: executable scenarios and trace display.
- `Audit.lean`: inspection of the proof dependencies.

The next integration step is an interpreter for these effects and callbacks,
using the same executable policy core. Its first backend obligation is to
demonstrate local-only Docker/devcontainer creation under the contracts above.
