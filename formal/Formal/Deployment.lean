import Std

/-!
A separate store/profile transition system. Store identifiers stand for trusted
immutable build outputs, not expressions in NixLang. No theorem here asserts
that hashing, builders, OS permissions, or filesystem rename implement this model.
-/
namespace Formal.Deployment

abbrev ObjectId := Nat
abbrev User := Nat

structure Artifact where
  dependencies : List ObjectId
  content : String
  deriving DecidableEq, Repr, BEq

abbrev Store := ObjectId → Option Artifact

structure Generation where
  serial : Nat
  roots : List ObjectId
  deriving DecidableEq, Repr, BEq

structure Profile where
  nextSerial : Nat := 0
  generations : List Generation := []
  active : Option Generation := none
  staged : Option (List ObjectId) := none
  deriving DecidableEq, Repr, BEq

structure State where
  store : Store
  profiles : User → Profile

def empty : State := ⟨fun _ => none, fun _ => {}⟩

def update {α : Type} (f : Nat → α) (key : Nat) (value : α) : Nat → α :=
  fun x => if x = key then value else f x

@[simp] theorem update_same {α : Type} (f : Nat → α) (key : Nat) (value : α) :
    update f key value key = value := by simp [update]

@[simp] theorem update_other {α : Type} (f : Nat → α) (key x : Nat) (value : α)
    (h : x ≠ key) : update f key value x = f x := by simp [update, h]

def Present (store : Store) (id : ObjectId) : Prop := ∃ a, store id = some a
def Ready (store : Store) (roots : List ObjectId) : Prop := ∀ id ∈ roots, Present store id

def StoreClosed (store : Store) : Prop :=
  ∀ id a, store id = some a → Ready store a.dependencies

structure ProfileOK (store : Store) (p : Profile) : Prop where
  generationsReady : ∀ g ∈ p.generations, Ready store g.roots
  stagedReady : ∀ roots, p.staged = some roots → Ready store roots
  activeRetained : ∀ g, p.active = some g → g ∈ p.generations
  serialBound : ∀ g ∈ p.generations, g.serial < p.nextSerial
  uniqueSerials : (p.generations.map Generation.serial).Nodup

structure Invariant (s : State) : Prop where
  closed : StoreClosed s.store
  profiles : ∀ u, ProfileOK s.store (s.profiles u)

theorem empty_invariant : Invariant empty := by
  constructor
  · intro id a h; cases h
  · intro u
    constructor <;> simp [empty]

/-- Every saved generation is a GC root, not just the active generation.
Staged outputs are pinned too, closing the stage/activation GC race. -/
def ProfileRoot (p : Profile) (id : ObjectId) : Prop :=
  (∃ g ∈ p.generations, id ∈ g.roots) ∨ (∃ roots, p.staged = some roots ∧ id ∈ roots)

def Root (s : State) (id : ObjectId) : Prop := ∃ u, ProfileRoot (s.profiles u) id

inductive Reachable (store : Store) (roots : ObjectId → Prop) : ObjectId → Prop where
  | root {id : ObjectId} : roots id → Reachable store roots id
  | dependency {id dep : ObjectId} {a : Artifact} :
      Reachable store roots id → store id = some a → dep ∈ a.dependencies →
      Reachable store roots dep

theorem rooted_present {s : State} (h : Invariant s) {id : ObjectId}
    (root : Root s id) : Present s.store id := by
  obtain ⟨u, hg | hs⟩ := root
  · obtain ⟨g, hg, hi⟩ := hg
    exact (h.profiles u).generationsReady g hg id hi
  · obtain ⟨roots, hs, hi⟩ := hs
    exact (h.profiles u).stagedReady roots hs id hi

theorem closure_present {s : State} (h : Invariant s) {id : ObjectId}
    (reach : Reachable s.store (Root s) id) : Present s.store id := by
  induction reach with
  | root r => exact rooted_present h r
  | dependency r stored member ih => exact h.closed _ _ stored _ member

def build (s : State) (id : ObjectId) (a : Artifact) : State :=
  { s with store := update s.store id (some a) }

def stage (s : State) (u : User) (roots : List ObjectId) : State :=
  { s with profiles := update s.profiles u { s.profiles u with staged := some roots } }

def activate (s : State) (u : User) (roots : List ObjectId) : State :=
  let p := s.profiles u
  let g : Generation := ⟨p.nextSerial, roots⟩
  let next : Profile :=
    { nextSerial := p.nextSerial + 1
      generations := g :: p.generations
      active := some g
      staged := none }
  { s with profiles := update s.profiles u next }

def rollback (s : State) (u : User) (g : Generation) : State :=
  { s with profiles := update s.profiles u { s.profiles u with active := some g } }

/-- Drop only inactive generations. The active root cannot be removed this way. -/
def forget (s : State) (u : User) (serial : Nat) : State :=
  let p := s.profiles u
  let history := p.generations.filter (fun g => g.serial != serial || decide (p.active = some g))
  let next : Profile := { p with generations := history }
  { s with profiles := update s.profiles u next }

def collect (s : State) (keep : ObjectId → Bool) : State :=
  { s with store := fun id => if keep id then s.store id else none }

def KeepsRoots (s : State) (keep : ObjectId → Bool) : Prop :=
  ∀ id, Root s id → keep id = true

def KeepsDependencies (s : State) (keep : ObjectId → Bool) : Prop :=
  ∀ id a, s.store id = some a → keep id = true →
    ∀ dep ∈ a.dependencies, keep dep = true

/-- Preconditions are explicit: build uses a fresh identifier and completed
dependencies; activation uses the staged roots; rollback uses retained history;
GC retains roots and is closed under store dependencies. -/
inductive Transition : State → State → Prop where
  | build {id : ObjectId} : s.store id = none → Ready s.store a.dependencies →
      Transition s (build s id a)
  | stage : Ready s.store roots → Transition s (stage s u roots)
  | activate : (s.profiles u).staged = some roots → Transition s (activate s u roots)
  | rollback : g ∈ (s.profiles u).generations → Transition s (rollback s u g)
  | forget : Transition s (forget s u serial)
  | collect : KeepsRoots s keep → KeepsDependencies s keep → Transition s (collect s keep)

theorem build_preserves_existing {s : State} {id old : ObjectId} {a previous : Artifact}
    (fresh : s.store id = none) (stored : s.store old = some previous) :
    (build s id a).store old = some previous := by
  have ne : old ≠ id := by intro eq; subst old; rw [fresh] at stored; contradiction
  simp [build, ne, stored]

theorem ready_build {s : State} {id : ObjectId} {a : Artifact} {roots : List ObjectId}
    (fresh : s.store id = none) (ready : Ready s.store roots) :
    Ready (build s id a).store roots := by
  intro old member
  obtain ⟨previous, stored⟩ := ready old member
  exact ⟨previous, build_preserves_existing fresh stored⟩

theorem build_invariant {s : State} {id : ObjectId} {a : Artifact}
    (h : Invariant s) (fresh : s.store id = none) (deps : Ready s.store a.dependencies) :
    Invariant (build s id a) := by
  constructor
  · intro old previous stored
    by_cases eq : old = id
    · subst old
      have same : a = previous := by simpa [build] using stored
      subst previous
      exact ready_build fresh deps
    · have before : s.store old = some previous := by simpa [build, eq] using stored
      exact ready_build fresh (h.closed old previous before)
  · intro u
    have hp := h.profiles u
    exact ⟨fun g mem => ready_build fresh (hp.generationsReady g mem),
      fun roots staged => ready_build fresh (hp.stagedReady roots staged),
      hp.activeRetained, hp.serialBound, hp.uniqueSerials⟩

theorem stage_invariant {s : State} {u : User} {roots : List ObjectId}
    (h : Invariant s) (ready : Ready s.store roots) : Invariant (stage s u roots) := by
  constructor
  · exact h.closed
  · intro v
    by_cases eq : v = u
    · subst v
      simp only [stage, update_same]
      have hp := h.profiles u
      constructor
      · exact hp.generationsReady
      · intro rs hs; cases hs; exact ready
      · exact hp.activeRetained
      · exact hp.serialBound
      · exact hp.uniqueSerials
    · simpa [stage, eq] using h.profiles v

theorem activate_invariant {s : State} {u : User} {roots : List ObjectId}
    (h : Invariant s) (staged : (s.profiles u).staged = some roots) :
    Invariant (activate s u roots) := by
  constructor
  · exact h.closed
  · intro v
    by_cases eq : v = u
    · subst v
      simp only [activate, update_same]
      have hp := h.profiles u
      constructor
      · intro g mem
        rcases List.mem_cons.mp mem with eq | mem
        · subst g; exact hp.stagedReady roots staged
        · exact hp.generationsReady g mem
      · intro rs hs; cases hs
      · intro g hg; cases hg; exact List.mem_cons_self
      · intro g mem
        rcases List.mem_cons.mp mem with eq | mem
        · subst g; exact Nat.lt_succ_self _
        · exact Nat.lt_trans (hp.serialBound g mem) (Nat.lt_succ_self _)
      · simp only [List.map_cons, List.nodup_cons]
        constructor
        · intro mem
          obtain ⟨g, hg, serial⟩ := List.mem_map.mp mem
          have bound := hp.serialBound g hg
          omega
        · exact hp.uniqueSerials
    · simpa [activate, eq] using h.profiles v

theorem rollback_invariant {s : State} {u : User} {g : Generation}
    (h : Invariant s) (retained : g ∈ (s.profiles u).generations) :
    Invariant (rollback s u g) := by
  constructor
  · exact h.closed
  · intro v
    by_cases eq : v = u
    · subst v
      simp only [rollback, update_same]
      have hp := h.profiles u
      constructor
      · exact hp.generationsReady
      · exact hp.stagedReady
      · intro g' hg; cases hg; exact retained
      · exact hp.serialBound
      · exact hp.uniqueSerials
    · simpa [rollback, eq] using h.profiles v

theorem forget_invariant {s : State} {u : User} {serial : Nat}
    (h : Invariant s) : Invariant (forget s u serial) := by
  constructor
  · exact h.closed
  · intro v
    by_cases eq : v = u
    · subst v
      simp only [forget, update_same]
      have hp := h.profiles u
      constructor
      · intro g mem; exact hp.generationsReady g (List.mem_filter.mp mem).1
      · exact hp.stagedReady
      · intro g active
        change (s.profiles u).active = some g at active
        apply List.mem_filter.mpr
        exact ⟨hp.activeRetained g active, by simp [active]⟩
      · intro g mem; exact hp.serialBound g (List.mem_filter.mp mem).1
      · exact (List.Sublist.map Generation.serial List.filter_sublist).nodup hp.uniqueSerials
    · simpa [forget, eq] using h.profiles v

theorem kept_present {s : State} {keep : ObjectId → Bool} {id : ObjectId}
    (present : Present s.store id) (kept : keep id = true) :
    Present (collect s keep).store id := by
  simpa [Present, collect, kept] using present

theorem collect_invariant {s : State} {keep : ObjectId → Bool}
    (h : Invariant s) (roots : KeepsRoots s keep) (deps : KeepsDependencies s keep) :
    Invariant (collect s keep) := by
  constructor
  · intro id a stored
    have kept : keep id = true := by
      cases hk : keep id <;> simp_all [collect]
    have before : s.store id = some a := by simpa [collect, kept] using stored
    intro dep member
    exact kept_present (h.closed id a before dep member) (deps id a before kept dep member)
  · intro u
    have hp := h.profiles u
    constructor
    · intro g member id inRoots
      exact kept_present (hp.generationsReady g member id inRoots)
        (roots id ⟨u, Or.inl ⟨g, member, inRoots⟩⟩)
    · intro rs staged id inRoots
      exact kept_present (hp.stagedReady rs staged id inRoots)
        (roots id ⟨u, Or.inr ⟨rs, staged, inRoots⟩⟩)
    · exact hp.activeRetained
    · exact hp.serialBound
    · exact hp.uniqueSerials

theorem transition_invariant {s t : State} (h : Invariant s) (step : Transition s t) :
    Invariant t := by
  cases step with
  | build fresh deps => exact build_invariant h fresh deps
  | stage ready => exact stage_invariant h ready
  | activate staged => exact activate_invariant h staged
  | rollback retained => exact rollback_invariant h retained
  | forget => exact forget_invariant h
  | collect roots deps => exact collect_invariant h roots deps

inductive Trace : State → State → Prop where
  | refl : Trace s s
  | cons : Transition s t → Trace t u → Trace s u

theorem trace_invariant {s t : State} (h : Invariant s) (trace : Trace s t) : Invariant t := by
  induction trace with
  | refl => exact h
  | cons step rest ih => exact ih (transition_invariant h step)

/-- Atomic activation exposes one complete retained generation in one step. -/
theorem activation_complete {s : State} {u : User} {roots : List ObjectId}
    (h : Invariant s) (staged : (s.profiles u).staged = some roots) :
    Ready (activate s u roots).store roots ∧
    ((activate s u roots).profiles u).active = some ⟨(s.profiles u).nextSerial, roots⟩ := by
  exact ⟨(h.profiles u).stagedReady roots staged, by simp [activate]⟩

theorem active_closure_present {s : State} (h : Invariant s) {u : User} {g : Generation}
    (active : (s.profiles u).active = some g) {id : ObjectId}
    (reachable : Reachable s.store (fun x => x ∈ g.roots) id) : Present s.store id := by
  induction reachable with
  | root member =>
      exact (h.profiles u).generationsReady g
        ((h.profiles u).activeRetained g active) _ member
  | dependency reach stored member ih => exact h.closed _ _ stored _ member

theorem stage_does_not_activate (s : State) (u : User) (roots : List ObjectId) :
    ((stage s u roots).profiles u).active = (s.profiles u).active := by simp [stage]

theorem build_does_not_activate (s : State) (id : ObjectId) (a : Artifact) (u : User) :
    ((build s id a).profiles u).active = (s.profiles u).active := rfl

theorem stage_other_user (s : State) (u v : User) (roots : List ObjectId) (ne : v ≠ u) :
    (stage s u roots).profiles v = s.profiles v := by simp [stage, ne]

theorem activate_other_user (s : State) (u v : User) (roots : List ObjectId) (ne : v ≠ u) :
    (activate s u roots).profiles v = s.profiles v := by simp [activate, ne]

theorem rollback_other_user (s : State) (u v : User) (g : Generation) (ne : v ≠ u) :
    (rollback s u g).profiles v = s.profiles v := by simp [rollback, ne]

theorem forget_other_user (s : State) (u v : User) (serial : Nat) (ne : v ≠ u) :
    (forget s u serial).profiles v = s.profiles v := by simp [forget, ne]

theorem rollback_restores (s : State) (u : User) (g : Generation) :
    ((rollback s u g).profiles u).active = some g := by simp [rollback]

theorem gc_keeps_closure {s : State} {keep : ObjectId → Bool}
    (roots : KeepsRoots s keep) (deps : KeepsDependencies s keep) {id : ObjectId}
    (reach : Reachable s.store (Root s) id) : keep id = true := by
  induction reach with
  | root r => exact roots _ r
  | dependency r stored member ih => exact deps _ _ stored ih _ member

/-- GC preserves the exact bytes/dependency record of every reachable object. -/
theorem gc_preserves_reachable {s : State} {keep : ObjectId → Bool}
    (roots : KeepsRoots s keep) (deps : KeepsDependencies s keep) {id : ObjectId}
    (reach : Reachable s.store (Root s) id) :
    (collect s keep).store id = s.store id := by
  simp [collect, gc_keeps_closure roots deps reach]

theorem gc_preserves_profiles (s : State) (keep : ObjectId → Bool) :
    (collect s keep).profiles = s.profiles := rfl

/-! Executable commands reject invalid build/stage/activation/rollback requests.
GC is the separately certified `collect` API: callers supply a closed keep set. -/

inductive Command where
  | build : ObjectId → Artifact → Command
  | stage : User → List ObjectId → Command
  | activate : User → Command
  | rollback : User → Nat → Command
  | forget : User → Nat → Command
  deriving Repr

inductive Error where
  | occupied | missingDependency | noStagedGeneration | unknownGeneration
  deriving DecidableEq, Repr, BEq

def readyCheck (store : Store) (roots : List ObjectId) : Bool :=
  roots.all (fun id => (store id).isSome)

theorem readyCheck_iff (store : Store) (roots : List ObjectId) :
    readyCheck store roots = true ↔ Ready store roots := by
  simp only [readyCheck, List.all_eq_true, Ready, Present]
  constructor
  · intro h id mem
    cases hs : store id with
    | none => have bad := h id mem; simp [hs] at bad
    | some a => exact ⟨a, rfl⟩
  · intro h id mem
    obtain ⟨a, hs⟩ := h id mem
    simp [hs]

def execute (s : State) : Command → Except Error State
  | .build id a =>
      if (s.store id).isSome then .error .occupied
      else if readyCheck s.store a.dependencies then .ok (build s id a)
      else .error .missingDependency
  | .stage u roots =>
      if readyCheck s.store roots then .ok (stage s u roots) else .error .missingDependency
  | .activate u =>
      match (s.profiles u).staged with
      | none => .error .noStagedGeneration
      | some roots => .ok (activate s u roots)
  | .rollback u serial =>
      match (s.profiles u).generations.find? (fun g => g.serial == serial) with
      | none => .error .unknownGeneration
      | some g => .ok (rollback s u g)
  | .forget u serial => .ok (forget s u serial)

theorem execute_transition {s t : State} {command : Command} (h : execute s command = .ok t) :
    Transition s t := by
  cases command with
  | build id a =>
      simp only [execute] at h
      split at h
      · contradiction
      · rename_i fresh
        split at h
        · rename_i ready
          cases h
          apply Transition.build
          · cases hs : s.store id <;> simp_all
          · exact (readyCheck_iff _ _).mp ready
        · contradiction
  | stage u roots =>
      simp only [execute] at h
      split at h
      · rename_i ready; cases h; exact .stage ((readyCheck_iff _ _).mp ready)
      · contradiction
  | activate u =>
      simp only [execute] at h
      split at h
      · contradiction
      · rename_i roots staged; cases h; exact .activate staged
  | rollback u serial =>
      simp only [execute] at h
      split at h
      · contradiction
      · rename_i g found
        cases h
        exact .rollback (List.mem_of_find?_eq_some found)
  | forget u serial => cases h; exact .forget

theorem execute_preserves {s t : State} {command : Command}
    (h : Invariant s) (success : execute s command = .ok t) : Invariant t :=
  transition_invariant h (execute_transition success)

/-- Public per-principal requests contain no field naming a different user.
An external caller supplies an authenticated principal to `executeFor`. -/
inductive Request where
  | build : ObjectId → Artifact → Request
  | stage : List ObjectId → Request
  | activate
  | rollback : Nat → Request
  | forget : Nat → Request
  deriving Repr

def Request.asCommand (u : User) : Request → Command
  | .build id a => .build id a
  | .stage roots => .stage u roots
  | .activate => .activate u
  | .rollback serial => .rollback u serial
  | .forget serial => .forget u serial

def executeFor (s : State) (principal : User) (request : Request) : Except Error State :=
  execute s (request.asCommand principal)

theorem executeFor_preserves {s t : State} {u : User} {request : Request}
    (h : Invariant s) (success : executeFor s u request = .ok t) : Invariant t :=
  execute_preserves h success

/-- This covers every public request, including shared-store builds. -/
theorem executeFor_other_user {s t : State} {u v : User} {request : Request}
    (success : executeFor s u request = .ok t) (other : v ≠ u) :
    t.profiles v = s.profiles v := by
  cases request with
  | build id a =>
      simp only [executeFor, Request.asCommand, execute] at success
      split at success
      · contradiction
      · split at success
        · cases success; rfl
        · contradiction
  | stage roots =>
      simp only [executeFor, Request.asCommand, execute] at success
      split at success
      · cases success; exact stage_other_user s u v roots other
      · contradiction
  | activate =>
      simp only [executeFor, Request.asCommand, execute] at success
      split at success
      · contradiction
      · cases success; exact activate_other_user s u v _ other
  | rollback serial =>
      simp only [executeFor, Request.asCommand, execute] at success
      split at success
      · contradiction
      · cases success; exact rollback_other_user s u v _ other
  | forget serial =>
      cases success; exact forget_other_user s u v serial other

def executeAll : State → List Command → Except Error State
  | s, [] => .ok s
  | s, command :: rest => (execute s command).bind (fun next => executeAll next rest)

theorem executeAll_preserves {s t : State} {commands : List Command}
    (h : Invariant s) (success : executeAll s commands = .ok t) : Invariant t := by
  induction commands generalizing s with
  | nil => cases success; exact h
  | cons command rest ih =>
      cases hc : execute s command with
      | error err => simp [executeAll, hc, Except.bind] at success
      | ok next =>
          exact ih (execute_preserves h hc) (by simpa [executeAll, hc, Except.bind] using success)

namespace Examples

def alice : User := 0
def bob : User := 1
def library : Artifact := ⟨[], "shared-runtime-v1"⟩
def appV1 : Artifact := ⟨[10], "editor-v1"⟩
def appV2 : Artifact := ⟨[10], "editor-v2"⟩
def bobApp : Artifact := ⟨[10], "analysis-tool"⟩
def unused : Artifact := ⟨[], "unused-build"⟩

def commands : List Command :=
  [.build 10 library, .build 11 appV1, .build 12 appV2, .build 13 bobApp, .build 99 unused,
   .stage alice [11], .activate alice,
   .stage bob [13], .activate bob,
   .stage alice [12], .activate alice,
   .rollback alice 0,
   .forget alice 1,
   .stage bob [12]]

def deployed : State :=
  build (build (build (build (build empty 10 library) 11 appV1) 12 appV2) 13 bobApp) 99 unused

def configured : State :=
  stage (forget (rollback
    (activate (stage
      (activate (stage
        (activate (stage deployed alice [11]) alice [11]) bob [13]) bob [13])
      alice [12]) alice [12]) alice ⟨0, [11]⟩) alice 1) bob [12]

example : executeAll empty commands = .ok configured := rfl

theorem configured_invariant : Invariant configured :=
  executeAll_preserves empty_invariant (show executeAll empty commands = .ok configured from rfl)

def keep (id : ObjectId) : Bool := id == 10 || id == 11 || id == 12 || id == 13

theorem example_keeps_roots : KeepsRoots configured keep := by
  intro id root
  obtain ⟨u, root⟩ := root
  by_cases ha : u = alice
  · subst u
    simp [ProfileRoot, configured, stage, forget, rollback, activate, deployed, build,
      update, alice, bob, empty] at root
    rcases root with rfl | rfl <;> decide
  · by_cases hb : u = bob
    · subst u
      simp [ProfileRoot, configured, stage, forget, rollback, activate, deployed, build,
        update, alice, bob, empty] at root
      rcases root with rfl | rfl <;> decide
    · simp [ProfileRoot, configured, stage, forget, rollback, activate, deployed, build,
        update, ha, hb, empty] at root

theorem example_keeps_dependencies : KeepsDependencies configured keep := by
  intro id a stored kept dep member
  simp [keep, Bool.or_eq_true, beq_iff_eq] at kept
  rcases kept with ((rfl | rfl) | rfl) | rfl <;>
    simp [configured, stage, forget, rollback, activate, deployed, build, update, empty] at stored <;>
    subst a <;> simp [library, appV1, appV2, bobApp] at member
  all_goals subst dep; decide

def collected : State := collect configured keep

theorem collected_invariant : Invariant collected :=
  collect_invariant configured_invariant example_keeps_roots example_keeps_dependencies

example : collected.store 99 = none := rfl
example : collected.store 10 = some library := rfl
example : collected.store 12 = some appV2 := rfl
example : (collected.profiles alice).active = some ⟨0, [11]⟩ := rfl
example : (collected.profiles bob).active = some ⟨0, [13]⟩ := rfl
example : (collected.profiles bob).staged = some [12] := rfl
example : execute collected (.build 10 unused) = .error .occupied := rfl
example : execute collected (.stage alice [404]) = .error .missingDependency := rfl
example : execute collected (.rollback alice 1) = .error .unknownGeneration := rfl

def report : List (String × String) :=
  [("alice", reprStr (collected.profiles alice)),
   ("bob", reprStr (collected.profiles bob)),
   ("store", reprStr ([10, 11, 12, 13, 99].map fun id => (id, collected.store id)))]

end Examples
end Formal.Deployment
