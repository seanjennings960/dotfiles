import DevCreation.Model

namespace DevCreation

/-- Every published receipt agrees with the artifact's locked identity. -/
def Verified (store : Store) : Prop :=
  ∀ receipt ∈ store, receipt.measuredDigest = receipt.request.artifact.digest

def PendingValid (lock : Lock) (grant : Grant) : Option Pending → Prop
  | none => True
  | some (.downloading _ request) =>
      request.artifact ∈ lock.inputs ∧ allows grant request.artifact.registry request.origin = true
  | some (.publishing _ receipt) =>
      receipt.request.artifact ∈ lock.inputs ∧
      allows grant receipt.request.artifact.registry receipt.request.origin = true ∧
      receipt.measuredDigest = receipt.request.artifact.digest

/-- Creation keeps its entire locked input set; a pending publication is verified. -/
def WellFormed (s : State) : Prop :=
  Verified s.store ∧ match s.phase with
    | .idle => True
    | .fetching _ lock grant pending => lock.valid = true ∧ PendingValid lock grant pending
    | .building _ lock | .settingUp _ lock => lock.valid = true ∧ complete s.store lock = true

def Authorized (s : State) (run : RunId) (request : Request) : Prop :=
  ∃ lock grant pending,
    s.phase = .fetching run lock grant pending ∧
    request.artifact ∈ lock.inputs ∧
    allows grant request.artifact.registry request.origin = true

/-- Backend requests must satisfy these independently stated contracts. -/
def SafeEffect (s : State) : Effect → Prop
  | .download run _ request => Authorized s run request
  | .publish run _ receipt =>
      Authorized s run receipt.request ∧ receipt.measuredDigest = receipt.request.artifact.digest
  | .build _ lock network =>
      s.phase = .idle ∧ network = .none ∧ lock.valid = true ∧ complete s.store lock = true
  | .setup run lock network =>
      s.phase = .building run lock ∧ network = .none ∧ complete s.store lock = true

theorem initial_wellFormed : WellFormed initial := by
  simp [WellFormed, Verified, initial]

/-- The actual executable transition preserves the invariant on every accepted input. -/
theorem step_preserves_wellFormed (valid : WellFormed s)
    (accepted : step s input = .ok (next, effects)) : WellFormed next := by
  rcases s with ⟨phase, store, nextRun, nextTransfer, outcome⟩
  cases input <;> cases phase <;>
    simp_all [step, WellFormed, PendingValid, Verified, Phase.runId]
  all_goals
    repeat first
      | (split at accepted <;> simp_all)
      | (rcases accepted with ⟨rfl, rfl⟩ <;> simp_all)
  all_goals grind

/-- Every emitted effect, including each redirected download, obeys the contract. -/
theorem step_effects_safe (valid : WellFormed s)
    (accepted : step s input = .ok (next, effects)) :
    ∀ effect ∈ effects, SafeEffect s effect := by
  rcases s with ⟨phase, store, nextRun, nextTransfer, outcome⟩
  cases input <;> cases phase <;>
    simp_all [step, WellFormed, PendingValid, SafeEffect, Authorized, Phase.runId]
  all_goals
    repeat first
      | (split at accepted <;> simp_all)
      | (rcases accepted with ⟨rfl, rfl⟩ <;> simp_all)
  all_goals grind

/-- A rejected input neither mutates state nor issues an effect. -/
theorem rejection_is_noop (rejected : step s input = .error error) :
    applyInput s input = (s, []) := by
  simp [applyInput, rejected]

theorem applyInput_preserves_wellFormed (valid : WellFormed s) :
    WellFormed (applyInput s input).1 := by
  unfold applyInput
  cases result : step s input with
  | error error => exact valid
  | ok transition =>
      rcases transition with ⟨next, effects⟩
      exact step_preserves_wellFormed valid result

/-- Induction over arbitrary-length command/callback sequences, including rejections. -/
theorem execute_preserves_wellFormed (valid : WellFormed s) :
    WellFormed (execute s inputs).1 := by
  induction inputs generalizing s with
  | nil => exact valid
  | cons input rest ih =>
      simp only [execute]
      exact ih (applyInput_preserves_wellFormed valid)

inductive Reachable : State → Prop where
  | start : Reachable initial
  | advance : Reachable s → Reachable (applyInput s input).1

theorem reachable_wellFormed (reachable : Reachable s) : WellFormed s := by
  induction reachable with
  | start => exact initial_wellFormed
  | advance _ ih => exact applyInput_preserves_wellFormed ih

theorem reachable_effects_safe (reachable : Reachable s)
    (accepted : step s input = .ok (next, effects)) :
    ∀ effect ∈ effects, SafeEffect s effect :=
  step_effects_safe (reachable_wellFormed reachable) accepted

/-- A grant/lock may only be installed by beginFetch; other inputs preserve the pair. -/
theorem grant_only_from_beginFetch
    (accepted : step s input = .ok (next, effects))
    (fetching : next.phase = .fetching run lock grant pending) :
    input = .beginFetch lock grant ∨
    ∃ previous, s.phase = .fetching run lock grant previous := by
  rcases s with ⟨phase, store, nextRun, nextTransfer, outcome⟩
  cases input <;> cases phase <;> simp_all [step, Phase.runId]
  all_goals
    repeat first
      | (split at accepted <;> simp_all)
      | (rcases accepted with ⟨rfl, rfl⟩ <;> simp_all)
  all_goals grind

/-- Failure does not discard previously published inputs, even after a partial fetch. -/
theorem failure_preserves_store
    (accepted : step s (.backendFailed run) = .ok (next, effects)) :
    next.store = s.store ∧ next.phase = .idle ∧ effects = [] := by
  rcases s with ⟨phase, store, nextRun, nextTransfer, outcome⟩
  cases phase <;> simp_all [step, Phase.runId]
  all_goals split at accepted <;> simp_all
  all_goals rcases accepted with ⟨rfl, rfl⟩; simp

/-- The modeled lease excludes deletion or mutation throughout build and setup. -/
theorem creation_preserves_store
    (creating : s.phase = .building run lock ∨ s.phase = .settingUp run lock)
    (accepted : step s input = .ok (next, effects)) : next.store = s.store := by
  rcases creating with building | settingUp
  · cases input <;> simp_all [step, Phase.runId]
    all_goals split at accepted <;> simp_all
    all_goals rcases accepted with ⟨rfl, rfl⟩; rfl
  · cases input <;> simp_all [step, Phase.runId]
    all_goals split at accepted <;> simp_all
    all_goals rcases accepted with ⟨rfl, rfl⟩; rfl

/-- No accepted input can cause a download while creation is active. -/
theorem creation_never_downloads
    (creating : s.phase = .building run lock ∨ s.phase = .settingUp run lock)
    (reachable : Reachable s)
    (accepted : step s input = .ok (next, effects)) :
    Effect.download downloadRun transfer request ∉ effects := by
  intro member
  have authorized := reachable_effects_safe reachable accepted _ member
  rcases authorized with ⟨_, _, _, fetching, _, _⟩
  rcases creating with building | settingUp
  · simp [building] at fetching
  · simp [settingUp] at fetching

/-- Active operations reject another user operation, including a second fetch. -/
theorem no_overlapping_operations (busy : s.phase ≠ .idle) :
    step s (.beginFetch lock grant) = .error .wrongPhase ∧
    step s (.beginCreate lock) = .error .wrongPhase := by
  cases phase : s.phase <;> simp_all [step]

/-- Deletion is only admitted when no operation is active. -/
theorem active_inputs_cannot_be_evicted (busy : s.phase ≠ .idle) :
    step s (.evict artifact) = .error .wrongPhase := by
  cases phase : s.phase <;> simp_all [step]

/-- A grant present after a trace either existed initially or came from its explicit command. -/
theorem execute_grant_origin
    (fetching : (execute s inputs).1.phase = .fetching run lock grant pending) :
    (∃ previous, s.phase = .fetching run lock grant previous) ∨
    Input.beginFetch lock grant ∈ inputs := by
  induction inputs generalizing s with
  | nil => exact .inl ⟨pending, fetching⟩
  | cons input rest ih =>
      change (execute (applyInput s input).1 rest).1.phase = _ at fetching
      rcases ih fetching with previous | command
      · rcases previous with ⟨previous, previousPhase⟩
        cases result : step s input with
        | error error =>
            simp only [applyInput, result] at previousPhase
            exact .inl ⟨previous, previousPhase⟩
        | ok transition =>
            rcases transition with ⟨next, effects⟩
            simp only [applyInput, result] at previousPhase
            rcases grant_only_from_beginFetch result previousPhase with command | inherited
            · exact .inr (List.mem_cons.mpr (.inl command.symm))
            · exact .inl inherited
      · exact .inr (List.mem_cons.mpr (.inr command))

/-- Every download after any finite prefix has an earlier explicit matching grant.
This quantifies over all command/callback sequences, not just the example traces. -/
theorem download_has_explicit_grant
    (accepted : step (execute initial history).1 input = .ok (next, effects))
    (member : Effect.download run transfer request ∈ effects) :
    ∃ lock grant,
      Input.beginFetch lock grant ∈ history ∧
      request.artifact ∈ lock.inputs ∧
      allows grant request.artifact.registry request.origin = true := by
  have safe := step_effects_safe (execute_preserves_wellFormed initial_wellFormed)
    accepted _ member
  rcases safe with ⟨lock, grant, pending, fetching, locked, allowed⟩
  rcases execute_grant_origin fetching with impossible | command
  · simp [initial] at impossible
  · exact ⟨lock, grant, command, locked, allowed⟩

/-- Both backend execution phases explicitly prohibit all network sockets. -/
theorem creation_effects_have_no_network (reachable : Reachable s)
    (accepted : step s input = .ok (next, effects))
    (member : Effect.build run lock network ∈ effects ∨
              Effect.setup run lock network ∈ effects) : network = .none := by
  rcases member with build | setup
  · exact (reachable_effects_safe reachable accepted _ build).2.1
  · exact (reachable_effects_safe reachable accepted _ setup).2.1

end DevCreation
