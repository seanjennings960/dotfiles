import Formal.STLC

/-!
Constructive termination for the nonrecursive language of `EvalSTLC.thy`.
The fundamental logical-relation theorem supplies successful finite fuel,
so the source's observational type-safety disjunction always holds on its
typed-constant side at base types. See ../NORMALIZATION.md.
-/

namespace STLC.Normalization

/-- A typed base value, or a typed closure that terminates on every reducible
argument and returns a reducible result. Recursion is on the simple type. -/
def Reducible : Ty → Val → Prop
  | .int, v => WtValue v .int
  | .bool, v => WtValue v .bool
  | .arrow a b, v =>
      WtValue v (.arrow a b) ∧
      ∃ i x body ρ, v = .closure i x a body ρ ∧
        ∀ w, Reducible a w →
          ∃ k v', interp body ((x, w) :: ρ) k = .result v' ∧ Reducible b v'

/-- Matching association lists preserve the source's first-binding shadowing. -/
inductive ReducibleEnv : TyEnv → Env → Prop where
  | nil : ReducibleEnv [] []
  | cons {v t Γ ρ x} :
      Reducible t v → ReducibleEnv Γ ρ →
      ReducibleEnv ((x, t) :: Γ) ((x, v) :: ρ)

theorem Reducible.typed {t : Ty} {v : Val} (h : Reducible t v) :
    WtValue v t := by
  cases t with
  | int => exact h
  | bool => exact h
  | arrow a b => exact h.1

theorem ReducibleEnv.typed {Γ : TyEnv} {ρ : Env} (h : ReducibleEnv Γ ρ) :
    WtEnv Γ ρ := by
  induction h with
  | nil => exact .nil
  | cons hv _ ih => exact .cons hv.typed ih

theorem reducible_lookup {Γ : TyEnv} {ρ : Env} {x : Name} {t : Ty}
    (hρ : ReducibleEnv Γ ρ) (hl : lookup Γ x = .result t) :
    ∃ v, lookup ρ x = .result v ∧ Reducible t v := by
  induction hρ with
  | nil => cases hl
  | @cons v a Γ ρ y hv _ ih =>
      by_cases hxy : x = y
      · change (if x = y then .result a else lookup Γ x) = .result t at hl
        rw [if_pos hxy] at hl
        cases hl
        exact ⟨v, if_pos hxy, hv⟩
      · have hl' : lookup Γ x = .result t := (if_neg hxy).symm.trans hl
        obtain ⟨w, hw, hr⟩ := ih hl'
        exact ⟨w, (if_neg hxy).trans hw, hr⟩

/-- The source's natural-number primitives are total on their typed inputs. -/
theorem reducible_delta {op : PrimOp} {a b : Ty} {v : Val}
    (hop : typeof_op op = .arrow a b) (hv : Reducible a v) :
    ∃ w, delta op v = .result w ∧ Reducible b w := by
  cases op <;> cases hop
  all_goals obtain ⟨i, j, n, rfl⟩ := int_value hv
  all_goals exact ⟨_, rfl, WtValue.const rfl⟩

-- Direct decidable comparisons keep these fuel bounds free of axioms too.
private theorem fuel_le_max_left (a b : Nat) : a ≤ max a b := by
  change a ≤ if a ≤ b then b else a
  by_cases h : a ≤ b
  · rw [if_pos h]
    exact h
  · rw [if_neg h]
    exact Nat.le_refl a

private theorem fuel_le_max_right (a b : Nat) : b ≤ max a b := by
  change b ≤ if a ≤ b then b else a
  by_cases h : a ≤ b
  · rw [if_pos h]
    exact Nat.le_refl b
  · rw [if_neg h]
    exact Nat.le_of_not_le h

/-- Fundamental theorem: every well-typed expression terminates in every
reducible environment, producing a reducible value at its assigned type. -/
theorem fundamental {Γ : TyEnv} {e : Expr} {t : Ty} {ρ : Env}
    (he : WtExpr Γ e t) (hρ : ReducibleEnv Γ ρ) :
    ∃ k v, interp e ρ k = .result v ∧ Reducible t v := by
  induction he generalizing ρ with
  | var hl =>
      obtain ⟨v, hv, hr⟩ := reducible_lookup hρ hl
      exact ⟨1, v, hv, hr⟩
  | const hc =>
      subst hc
      refine ⟨1, _, rfl, ?_⟩
      cases ‹Const› <;> exact WtValue.const rfl
  | @lam x a Γ body b i hb ih =>
      refine ⟨1, .closure i x a body ρ, rfl, ?_⟩
      refine ⟨WtValue.closure hb hρ.typed, i, x, body, ρ, rfl, ?_⟩
      intro w hw
      exact ih (.cons hw hρ)
  | @primApp op a b Γ e i hop he ih =>
      obtain ⟨k, v, hv, hr⟩ := ih hρ
      obtain ⟨w, hw, hwr⟩ := reducible_delta hop hr
      refine ⟨k + 1, w, ?_, hwr⟩
      change result_bind (interp e ρ k) (delta op) = .result w
      rw [hv]
      exact hw
  | @app Γ e₁ a b e₂ i he₁ he₂ ih₁ ih₂ =>
      obtain ⟨k₁, v₁, hv₁, hr₁⟩ := ih₁ hρ
      obtain ⟨k₂, v₂, hv₂, hr₂⟩ := ih₂ hρ
      obtain ⟨_, j, x, body, ρ', rfl, happ⟩ := hr₁
      obtain ⟨k₃, v, hv, hr⟩ := happ v₂ hr₂
      let k := max k₁ (max k₂ k₃)
      have hs₁ := interp_result_stable (fuel_le_max_left k₁ (max k₂ k₃)) hv₁
      have hs₂ := interp_result_stable
        (Nat.le_trans (fuel_le_max_left k₂ k₃) (fuel_le_max_right k₁ (max k₂ k₃))) hv₂
      have hs₃ := interp_result_stable
        (Nat.le_trans (fuel_le_max_right k₂ k₃) (fuel_le_max_right k₁ (max k₂ k₃))) hv
      refine ⟨k + 1, v, ?_, hr⟩
      change result_bind (interp e₁ ρ k) _ = .result v
      rw [hs₁]
      change result_bind (interp e₂ ρ k) _ = .result v
      rw [hs₂]
      exact hs₃
  | @ifE Γ cond yes t no i hc ht hf ihc iht ihf =>
      obtain ⟨k₁, v₁, hv₁, hr₁⟩ := ihc hρ
      obtain ⟨j, j', b, rfl⟩ := bool_value hr₁
      cases b with
      | false =>
          obtain ⟨k₂, v₂, hv₂, hr₂⟩ := ihf hρ
          have hs₁ := interp_result_stable (fuel_le_max_left k₁ k₂) hv₁
          have hs₂ := interp_result_stable (fuel_le_max_right k₁ k₂) hv₂
          refine ⟨max k₁ k₂ + 1, v₂, ?_, hr₂⟩
          change result_bind (interp cond ρ (max k₁ k₂)) _ = .result v₂
          rw [hs₁]
          exact hs₂
      | true =>
          obtain ⟨k₂, v₂, hv₂, hr₂⟩ := iht hρ
          have hs₁ := interp_result_stable (fuel_le_max_left k₁ k₂) hv₁
          have hs₂ := interp_result_stable (fuel_le_max_right k₁ k₂) hv₂
          refine ⟨max k₁ k₂ + 1, v₂, ?_, hr₂⟩
          change result_bind (interp cond ρ (max k₁ k₂)) _ = .result v₂
          rw [hs₁]
          exact hs₂

/-- Termination holds at all simple types, including function types. -/
theorem closed_terminates {e : Expr} {t : Ty} (he : WtExpr [] e t) :
    ∃ k v, interp e [] k = .result v ∧ WtValue v t := by
  obtain ⟨k, v, hv, hr⟩ := fundamental he .nil
  exact ⟨k, v, hv, hr.typed⟩

/-- At the source's observable types, termination returns a typed constant. -/
theorem base_terminates {e : Expr} {t : Ty} (he : WtExpr [] e t)
    (ht : t = .int ∨ t = .bool) :
    ∃ k i c, interp e [] k = .result (.const i c) ∧ typeof c = t := by
  obtain ⟨k, v, hv, hw⟩ := closed_terminates he
  rcases ht with rfl | rfl
  · obtain ⟨i, j, n, rfl⟩ := int_value hw
    exact ⟨k, i, .int j n, hv, rfl⟩
  · obtain ⟨i, j, b, rfl⟩ := bool_value hw
    exact ⟨k, i, .bool j b, hv, rfl⟩

/-- The exact source disjunction, constructively proved by its right branch. -/
theorem type_safety {e : Expr} {t : Ty} (he : WtExpr [] e t)
    (ht : t = .int ∨ t = .bool) :
    Eval e .diverge ∨ ∃ c, Eval e (.const c) ∧ typeof c = t := by
  obtain ⟨_, _, c, hv, hc⟩ := base_terminates he ht
  exact Or.inr ⟨c, Eval.evalc hv, hc⟩

/-- A closed well-typed term cannot have the source's divergence observation. -/
theorem closed_not_diverge {e : Expr} {t : Ty} (he : WtExpr [] e t) :
    ¬ Eval e .diverge := by
  obtain ⟨k, v, hv, _⟩ := closed_terminates he
  intro hd
  cases hd with
  | evald h =>
      rw [h k] at hv
      cases hv

#print axioms fundamental
#print axioms closed_terminates
#print axioms type_safety
#print axioms closed_not_diverge

end STLC.Normalization
