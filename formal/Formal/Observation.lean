import Std

/-! Constructive partial computations: coherent finite observations, without a
    decision between eventual return and infinite delay. No classical choice. -/
namespace Observation

structure Partial (α : Type) where
  observe : Nat → Option α
  stable : ∀ {n m a}, n ≤ m → observe n = some a → observe m = some a

namespace Partial

def Returns (p : Partial α) (a : α) : Prop := ∃ n, p.observe n = some a
def Diverges (p : Partial α) : Prop := ∀ n, p.observe n = none

def pure (a : α) : Partial α where
  observe := fun _ => some a
  stable := by intros; assumption

def never : Partial α where
  observe := fun _ => none
  stable := by intros _ _ _ _ h; cases h

def map (f : α → β) (p : Partial α) : Partial β where
  observe := fun n => (p.observe n).map f
  stable := by
    intro n m b le h
    cases hn : p.observe n with
    | none => simp [hn] at h
    | some a =>
      have hm := p.stable le hn
      simpa [hn, hm] using h

/-- Diagonal observation suffices: stability lets both stages share a budget. -/
def bind (p : Partial α) (f : α → Partial β) : Partial β where
  observe := fun n => (p.observe n).bind (fun a => (f a).observe n)
  stable := by
    intro n m b le h
    cases hn : p.observe n with
    | none => simp [hn] at h
    | some a =>
      have hm := p.stable le hn
      simp only [hn, Option.bind_some] at h
      simp only [hm, Option.bind_some]
      exact (f a).stable le h

theorem bind_returns (p : Partial α) (f : α → Partial β) (b : β) :
    (p.bind f).Returns b ↔ ∃ a, p.Returns a ∧ (f a).Returns b := by
  constructor
  · rintro ⟨n, hn⟩
    change (p.observe n).bind (fun a => (f a).observe n) = some b at hn
    cases hp : p.observe n with
    | none => simp [hp] at hn
    | some a =>
      exact ⟨a, ⟨n, hp⟩, ⟨n, by simpa [hp] using hn⟩⟩
  · rintro ⟨a, ⟨n, hn⟩, ⟨m, hm⟩⟩
    refine ⟨max n m, ?_⟩
    change (p.observe (max n m)).bind _ = some b
    rw [p.stable (Nat.le_max_left n m) hn]
    exact (f a).stable (Nat.le_max_right n m) hm

theorem returns_unique (p : Partial α) (ha : p.Returns a) (hb : p.Returns b) : a = b := by
  obtain ⟨n, hn⟩ := ha
  obtain ⟨m, hm⟩ := hb
  have h₁ := p.stable (Nat.le_max_left n m) hn
  have h₂ := p.stable (Nat.le_max_right n m) hm
  exact Option.some.inj (h₁.symm.trans h₂)

/-- This equivalence is constructive; choosing either side of a termination
    disjunction is an additional, unnecessary obligation. -/
theorem diverges_iff_no_return (p : Partial α) :
    p.Diverges ↔ ¬ ∃ a, p.Returns a := by
  constructor
  · intro h ⟨a, n, hn⟩
    rw [h n] at hn
    cases hn
  · intro h n
    cases hn : p.observe n with
    | none => rfl
    | some a => exact False.elim (h ⟨a, n, hn⟩)

/-- A checked partial computation carries pointwise evidence, not an oracle. -/
structure Safe (p : Partial α) (P : α → Prop) : Prop where
  returned : ∀ n a, p.observe n = some a → P a

def certify (p : Partial α) (h : p.Safe P) : Partial {a // P a} where
  observe := fun n => match hn : p.observe n with
    | none => none
    | some a => some ⟨a, h.returned n a hn⟩
  stable := by
    intro n m a le he
    split at he
    · cases he
    next b hb =>
      have hm := p.stable le hb
      split
      next hm0 => cases hm0.symm.trans hm
      next c hc =>
        apply congrArg some
        apply Subtype.ext
        exact (Option.some.inj (hc.symm.trans hm)).trans
          (congrArg Subtype.val (Option.some.inj he))

theorem certify_observe (p : Partial α) (h : p.Safe P) (n : Nat) :
    ((p.certify h).observe n).map Subtype.val = p.observe n := by
  simp only [certify]
  split <;> simp_all

/-- A fault is an observation, never an alternative spelling of pending. -/
def Good (P : α → Prop) : Except ε α → Prop
  | .ok a => P a
  | .error _ => False

def successful (v : {r : Except ε α // Good P r}) : {a // P a} :=
  match v with
  | ⟨.ok a, h⟩ => ⟨a, h⟩
  | ⟨.error _, h⟩ => False.elim h

/-- Constructively extract a typed partial value from a safe computation. -/
def values (p : Partial (Except ε α)) (h : p.Safe (Good P)) : Partial {a // P a} :=
  (p.certify h).map successful

theorem values_observe (p : Partial (Except ε α)) (h : p.Safe (Good P)) (n : Nat) :
    ((p.values h).observe n).map (fun v => Except.ok v.val) = p.observe n := by
  change (((p.certify h).observe n).map successful).map _ = _
  calc
    _ = ((p.certify h).observe n).map Subtype.val := by
      cases hv : (p.certify h).observe n with
      | none => rfl
      | some v =>
        obtain ⟨r, hr⟩ := v
        cases r with
        | error err => exact False.elim hr
        | ok a => rfl
    _ = p.observe n := certify_observe p h n

end Partial

/-- A finite, executable first-hit search of an arbitrary Boolean stream. -/
def search (b : Nat → Bool) : Nat → Option Nat
  | 0 => none
  | n + 1 => match search b n with
    | some k => some k
    | none => if b n then some n else none

theorem search_step (b : Nat → Bool) (h : search b n = some k) :
    search b (n + 1) = some k := by simp [search, h]

theorem search_stable (b : Nat → Bool) {n m k : Nat} (le : n ≤ m)
    (h : search b n = some k) : search b m = some k := by
  induction le with
  | refl => exact h
  | step _ ih => exact search_step b ih

theorem search_hit (b : Nat → Bool) (h : search b n = some k) : b k = true := by
  induction n with
  | zero => cases h
  | succ n ih =>
    simp only [search] at h
    split at h
    next j hj =>
      cases Option.some.inj h
      exact ih hj
    next hn =>
      split at h
      next ht =>
        cases Option.some.inj h
        exact ht
      next hf => cases h

theorem search_none (b : Nat → Bool) (h : search b (n + 1) = none) : b n = false := by
  simp only [search] at h
  split at h
  · cases h
  · cases hb : b n <;> simp_all

def searching (b : Nat → Bool) : Partial Nat where
  observe := search b
  stable := search_stable b

def LPO : Prop := ∀ b : Nat → Bool, (∀ n, b n = false) ∨ ∃ n, b n = true

/-- The unrestricted global termination/delay split entails limited
    omniscience. We expose this logical cost instead of importing it. -/
theorem dichotomy_implies_lpo
    (split : ∀ p : Partial Nat, p.Diverges ∨ ∃ a, p.Returns a) : LPO := by
  intro b
  cases split (searching b) with
  | inl h => exact Or.inl (fun n => search_none b (h (n + 1)))
  | inr h =>
    obtain ⟨a, n, hn⟩ := h
    exact Or.inr ⟨a, search_hit b hn⟩

theorem lpo_implies_dichotomy (lpo : LPO) (p : Partial α) :
    p.Diverges ∨ ∃ a, p.Returns a := by
  cases lpo (fun n => (p.observe n).isSome) with
  | inl h =>
    left
    intro n
    cases hn : p.observe n with
    | none => rfl
    | some a => have hf := h n; simp [hn] at hf
  | inr h =>
    obtain ⟨n, hn⟩ := h
    cases he : p.observe n with
    | none => simp [he] at hn
    | some a => exact Or.inr ⟨a, n, he⟩

#print axioms Partial.certify
#print axioms Partial.values_observe
#print axioms dichotomy_implies_lpo

end Observation
