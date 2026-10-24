import Std

/-!
An executable controller for separate acquisition and network-free creation.
Inputs are user commands or trusted backend observations. Effects are requests
to a backend, not implementations of downloads, hashing, Docker, or isolation.
-/

namespace DevCreation

abbrev RunId := Nat
abbrev TransferId := Nat
abbrev Origin := String
abbrev Digest := String

inductive Ecosystem where
  | oci | apt | pypi
  deriving Repr, DecidableEq

structure RegistryId where
  ecosystem : Ecosystem
  name : String
  deriving Repr, DecidableEq

structure Artifact where
  registry : RegistryId
  name : String
  version : String
  platform : String
  digest : Digest
  deriving Repr, DecidableEq

/-- Digests are opaque identities here, not an implementation of SHA-256. -/
def Artifact.pinned (a : Artifact) : Bool :=
  !a.name.isEmpty && !a.version.isEmpty && !a.platform.isEmpty && !a.digest.isEmpty

structure Lock where
  inputs : List Artifact
  deriving Repr, DecidableEq

def Lock.valid (lock : Lock) : Bool := lock.inputs.all Artifact.pinned

/-- A trusted, user-selected profile; origins must already be canonicalized. -/
structure RegistryProfile where
  registry : RegistryId
  origins : List Origin
  deriving Repr, DecidableEq

abbrev Grant := List RegistryProfile

def allows (grant : Grant) (registry : RegistryId) (origin : Origin) : Bool :=
  grant.any fun profile => profile.registry == registry && profile.origins.contains origin

structure Request where
  artifact : Artifact
  origin : Origin
  deriving Repr, DecidableEq

structure Receipt where
  request : Request
  measuredDigest : Digest
  deriving Repr, DecidableEq

abbrev Store := List Receipt

def available (store : Store) (a : Artifact) : Bool :=
  store.any fun receipt =>
    receipt.request.artifact == a && receipt.measuredDigest == a.digest

def complete (store : Store) (lock : Lock) : Bool := lock.inputs.all (available store)

inductive Pending where
  | downloading (transfer : TransferId) (request : Request)
  | publishing (transfer : TransferId) (receipt : Receipt)
  deriving Repr, DecidableEq

inductive Phase where
  | idle
  | fetching (run : RunId) (lock : Lock) (grant : Grant) (pending : Option Pending)
  | building (run : RunId) (lock : Lock)
  | settingUp (run : RunId) (lock : Lock)
  deriving Repr, DecidableEq

def Phase.runId : Phase → Option RunId
  | .idle => none
  | .fetching run .. | .building run .. | .settingUp run .. => some run

inductive Outcome where
  | fetched | created | failed
  deriving Repr, DecidableEq

structure State where
  phase : Phase := .idle
  store : Store := []
  nextRun : RunId := 0
  nextTransfer : TransferId := 0
  lastOutcome : Option (RunId × Outcome) := none
  deriving Repr, DecidableEq

def initial : State := {}

inductive Input where
  /-- Only this explicit user command installs a network grant. -/
  | beginFetch (lock : Lock) (grant : Grant)
  | request (artifact : Artifact) (origin : Origin)
  /-- The backend pauses before following a redirect and asks again. -/
  | redirected (run : RunId) (transfer : TransferId) (origin : Origin)
  | received (run : RunId) (transfer : TransferId) (measuredDigest : Digest)
  /-- The verified bytes have been atomically published in immutable storage. -/
  | published (run : RunId) (transfer : TransferId)
  | finishFetch (run : RunId)
  | beginCreate (lock : Lock)
  | buildFinished (run : RunId)
  /-- All finite setup work is done; survivors remain network-blocked. -/
  | setupFinished (run : RunId)
  /-- All outstanding work is quiescent; partial environments stay blocked. -/
  | backendFailed (run : RunId)
  | evict (artifact : Artifact)
  deriving Repr, DecidableEq

inductive Network where
  /-- No network sockets, including loopback. Local IPC is permitted. -/
  | none
  | unrestricted
  deriving Repr, DecidableEq

inductive Effect where
  | download (run : RunId) (transfer : TransferId) (request : Request)
  | publish (run : RunId) (transfer : TransferId) (receipt : Receipt)
  /-- Atomically recheck/lease inputs before executing; retain the lease through setup. -/
  | build (run : RunId) (lock : Lock) (network : Network)
  | setup (run : RunId) (lock : Lock) (network : Network)
  deriving Repr, DecidableEq

inductive Error where
  | wrongPhase | invalidLock | missingInputs | notLocked
  | originDenied | wrongRun | wrongTransfer | digestMismatch
  deriving Repr, DecidableEq

abbrev Transition := State × List Effect

/-- Rejection leaves state unchanged; `applyInput` supplies that execution rule. -/
def step (s : State) (input : Input) : Except Error Transition :=
  match s.phase, input with
  | .idle, .beginFetch lock grant =>
      if lock.valid then
        .ok ({ s with phase := .fetching s.nextRun lock grant none,
                      nextRun := s.nextRun + 1, lastOutcome := none }, [])
      else .error .invalidLock
  | .fetching run lock grant none, .request artifact origin =>
      if artifact ∈ lock.inputs then
        if available s.store artifact then .ok (s, [])
        else if allows grant artifact.registry origin then
          let request := { artifact, origin : Request }
          .ok ({ s with phase := .fetching run lock grant (some (.downloading s.nextTransfer request)),
                        nextTransfer := s.nextTransfer + 1 },
               [.download run s.nextTransfer request])
        else .error .originDenied
      else .error .notLocked
  | .fetching run lock grant (some (.downloading transfer request)),
      .redirected callback ticket origin =>
      if callback = run then
        if ticket = transfer then
          if allows grant request.artifact.registry origin then
            let redirected := { request with origin }
            .ok ({ s with phase := .fetching run lock grant
                            (some (.downloading s.nextTransfer redirected)),
                          nextTransfer := s.nextTransfer + 1 },
                 [.download run s.nextTransfer redirected])
          else .error .originDenied
        else .error .wrongTransfer
      else .error .wrongRun
  | .fetching run lock grant (some (.downloading transfer request)), .received callback ticket digest =>
      if callback = run then
        if ticket = transfer then
          if digest = request.artifact.digest then
            let receipt := { request, measuredDigest := digest : Receipt }
            .ok ({ s with phase := .fetching run lock grant (some (.publishing transfer receipt)) },
                 [.publish run transfer receipt])
          else .error .digestMismatch
        else .error .wrongTransfer
      else .error .wrongRun
  | .fetching run lock grant (some (.publishing transfer receipt)), .published callback ticket =>
      if callback = run then
        if ticket = transfer then
          .ok ({ s with phase := .fetching run lock grant none, store := receipt :: s.store }, [])
        else .error .wrongTransfer
      else .error .wrongRun
  | .fetching run lock _ none, .finishFetch callback =>
      if callback = run then
        if complete s.store lock then
          .ok ({ s with phase := .idle, lastOutcome := some (run, .fetched) }, [])
        else .error .missingInputs
      else .error .wrongRun
  | .idle, .beginCreate lock =>
      if lock.valid then
        if complete s.store lock then
          .ok ({ s with phase := .building s.nextRun lock,
                        nextRun := s.nextRun + 1, lastOutcome := none },
               [.build s.nextRun lock .none])
        else .error .missingInputs
      else .error .invalidLock
  | .building run lock, .buildFinished callback =>
      if callback = run then
        .ok ({ s with phase := .settingUp run lock }, [.setup run lock .none])
      else .error .wrongRun
  | .settingUp run _, .setupFinished callback =>
      if callback = run then
        .ok ({ s with phase := .idle, lastOutcome := some (run, .created) }, [])
      else .error .wrongRun
  | phase, .backendFailed callback =>
      if phase.runId = some callback then
        .ok ({ s with phase := .idle, lastOutcome := some (callback, .failed) }, [])
      else .error .wrongRun
  | .idle, .evict artifact =>
      .ok ({ s with store := s.store.filter (fun receipt => receipt.request.artifact != artifact) }, [])
  | _, _ => .error .wrongPhase

/-- A rejected command cannot mutate the controller or emit a backend effect. -/
def applyInput (s : State) (input : Input) : Transition :=
  match step s input with
  | .ok result => result
  | .error _ => (s, [])

/-- Execute an arbitrary finite sequence, retaining rejection's no-op semantics. -/
def execute (s : State) : List Input → Transition
  | [] => (s, [])
  | input :: rest =>
      let (next, effects) := applyInput s input
      let (final, later) := execute next rest
      (final, effects ++ later)

end DevCreation
