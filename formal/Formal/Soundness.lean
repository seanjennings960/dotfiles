import Formal.Observation
import Formal.STLC
import Formal.Recursive

/-! Constructive, unbounded evaluation objects for both source languages. -/
open Observation

namespace STLC

def observeResult : Result Val → Option (Except Unit Val)
  | .timeout => none
  | .stuck => some (.error ())
  | .result v => some (.ok v)

theorem observeResult_ok (r : Result Val) (v : Val) :
    observeResult r = some (.ok v) ↔ r = .result v := by
  cases r <;> simp [observeResult]

theorem observeResult_pending (r : Result Val) :
    observeResult r = none ↔ r = .timeout := by
  cases r <;> simp [observeResult]

/-- Untyped semantics retains faults as settled observations. -/
def evaluation (e : Expr) (ρ : Env := []) : Partial (Except Unit Val) where
  observe := fun k => observeResult (interp e ρ k)
  stable := by
    intro n m a le hn
    have hnt : interp e ρ n ≠ .timeout := by
      intro h
      rw [h] at hn
      cases hn
    rw [interp_stable le hnt]
    exact hn

theorem evaluation_safe (he : WtExpr Γ e T) (hρ : WtEnv Γ ρ) :
    (evaluation e ρ).Safe (Partial.Good (fun v => WtValue v T)) := by
  constructor
  intro k r hr
  have hs := interp_safe he hρ k
  change observeResult (interp e ρ k) = some r at hr
  generalize interp e ρ k = raw at hr hs
  cases hs with
  | timeout => cases hr
  | result hv =>
    cases hr
    exact hv

/-- The missing constructive conclusion is a typed partial value, with no
    unbounded termination test. -/
def soundness (he : WtExpr Γ e T) (hρ : WtEnv Γ ρ) :
    Partial {v : Val // WtValue v T} :=
  (evaluation e ρ).values (evaluation_safe he hρ)

theorem soundness_exact (he : WtExpr Γ e T) (hρ : WtEnv Γ ρ) (k : Nat) :
    ((soundness he hρ).observe k).map (fun v => Except.ok v.val) =
      observeResult (interp e ρ k) :=
  Partial.values_observe _ _ k

/-- The new evaluation definition has exactly the source's constant observations. -/
theorem source_constant_iff (e : Expr) (c : Const) :
    (∃ i, (evaluation e).Returns (.ok (.const i c))) ↔ Eval e (.const c) := by
  constructor
  · rintro ⟨i, k, hk⟩
    exact .evalc ((observeResult_ok _ _).mp hk)
  · intro h
    cases h with
    | evalc hk => exact ⟨_, _, (observeResult_ok _ _).mpr hk⟩

theorem source_divergence_iff (e : Expr) :
    (evaluation e).Diverges ↔ Eval e .diverge := by
  constructor
  · intro h
    exact .evald (fun k => (observeResult_pending _).mp (h k))
  · intro h
    cases h with
    | evald hk => exact fun k => (observeResult_pending _).mpr (hk k)

example : (evaluation Examples.badApplication).observe 2 = none := rfl
example : (evaluation Examples.badApplication).observe 3 = some (.error ()) := rfl

private theorem answer_typed : WtExpr [] Examples.answer .int :=
  .primApp rfl (.app (.lam (.var rfl)) (.const rfl))

-- These execute the proof-certified computation, not just the raw interpreter.
#eval ((soundness answer_typed .nil).observe 0).map (fun v => reprStr v.val)
#eval ((soundness answer_typed .nil).observe 4).map (fun v => reprStr v.val)

end STLC

namespace Recursive

def observeResult : Result Value → Option (Except Unit Value)
  | .timeout => none
  | .stuck => some (.error ())
  | .value v => some (.ok v)

theorem observeResult_ok (r : Result Value) (v : Value) :
    observeResult r = some (.ok v) ↔ r = .value v := by
  cases r <;> simp [observeResult]

theorem observeResult_pending (r : Result Value) :
    observeResult r = none ↔ r = .timeout := by
  cases r <;> simp [observeResult]

def evaluation (e : Expr) (ρ : Env := []) : Partial (Except Unit Value) where
  observe := fun k => observeResult (interp k ρ e)
  stable := by
    intro n m a le hn
    have hnt : interp n ρ e ≠ .timeout := by
      intro h
      rw [h] at hn
      cases hn
    rw [interp_stable le hnt]
    exact hn

theorem evaluation_safe (he : HasType Γ e T) (hρ : EnvTyped Γ ρ) :
    (evaluation e ρ).Safe (Partial.Good (fun v => ValueTyped v T)) := by
  constructor
  intro k r hr
  have hs := interp_safe he hρ k
  change observeResult (interp k ρ e) = some r at hr
  generalize interp k ρ e = raw at hr hs
  cases hs with
  | timeout => cases hr
  | value hv =>
    cases hr
    exact hv

def soundness (he : HasType Γ e T) (hρ : EnvTyped Γ ρ) :
    Partial {v : Value // ValueTyped v T} :=
  (evaluation e ρ).values (evaluation_safe he hρ)

/-- Forgetting the proof gives exactly the original interpreter observation. -/
theorem soundness_exact (he : HasType Γ e T) (hρ : EnvTyped Γ ρ) (k : Nat) :
    ((soundness he hρ).observe k).map (fun v => Except.ok v.val) =
      observeResult (interp k ρ e) :=
  Partial.values_observe _ _ k

theorem source_return_iff (e : Expr) (ρ : Env) (v : Value) :
    (evaluation e ρ).Returns (.ok v) ↔ Returns ρ e v := by
  constructor
  · rintro ⟨k, hk⟩
    exact ⟨k, (observeResult_ok _ _).mp hk⟩
  · rintro ⟨k, hk⟩
    exact ⟨k, (observeResult_ok _ _).mpr hk⟩

theorem source_divergence_iff (e : Expr) (ρ : Env) :
    (evaluation e ρ).Diverges ↔ Diverges ρ e := by
  constructor
  · exact fun h k => (observeResult_pending _).mp (h k)
  · exact fun h k => (observeResult_pending _).mpr (h k)

theorem evaluation_loop_diverges : (evaluation loop).Diverges := by
  intro k
  change observeResult (interp k [] loop) = none
  rw [loop_timeout]
  rfl

theorem evaluation_arithmetic_returns :
    (evaluation arithmetic).Returns (.ok (.const (.bool true))) := ⟨4, rfl⟩

#print axioms soundness
#print axioms soundness_exact

end Recursive
