import Std

/-! The literal language of Siek's "Type Safety in Three Easy Lemmas".
    Fuel measures evaluation depth; both operands receive the same smaller fuel. -/
namespace Recursive

inductive Ty where
  | int | bool
  | fn (arg result : Ty)
  deriving DecidableEq, Repr

inductive Const where
  | int (n : Int)
  | bool (b : Bool)
  deriving DecidableEq, Repr

def Const.type : Const → Ty
  | .int _ => .int
  | .bool _ => .bool

inductive Op where
  | add | sub | eq
  deriving DecidableEq, Repr

def Op.resultType : Op → Ty
  | .add | .sub => .int
  | .eq => .bool

def Delta (o : Op) : Ty → Ty → Option Ty
  | .int, .int => some o.resultType
  | _, _ => none

inductive Expr where
  | const (c : Const)
  | bin (o : Op) (left right : Expr)
  | var (x : String)
  | fn (self arg : String) (argType : Ty) (body : Expr)
  | app (fn arg : Expr)
  deriving DecidableEq, Repr

inductive Value where
  | const (c : Const)
  -- Only the old environment is captured: this is a finite, noncyclic value.
  | closure (self arg : String) (argType : Ty) (body : Expr)
      (captured : List (String × Value))

abbrev Env := List (String × Value)
abbrev Context := List (String × Ty)

inductive Result (α : Type) where
  | value (v : α)
  | stuck
  | timeout

def Result.bind (r : Result α) (f : α → Result β) : Result β :=
  match r with
  | .value v => f v
  | .stuck => .stuck
  | .timeout => .timeout

def lookup (x : String) : List (String × α) → Result α
  | [] => .stuck
  | (y, v) :: rest => if x = y then .value v else lookup x rest

def delta (o : Op) : Value → Value → Result Value
  | .const (.int m), .const (.int n) =>
      .value (.const (match o with
        | .add => .int (m + n)
        | .sub => .int (m - n)
        | .eq => .bool (decide (m = n))))
  | _, _ => .stuck

def interp : Nat → Env → Expr → Result Value
  | 0, _, _ => .timeout
  | _ + 1, _, .const c => .value (.const c)
  | _ + 1, ρ, .var x => lookup x ρ
  | _ + 1, ρ, .fn f x A body => .value (.closure f x A body ρ)
  | k + 1, ρ, .bin o a b =>
      (interp k ρ a).bind fun v =>
      (interp k ρ b).bind fun w => delta o v w
  | k + 1, ρ, .app a b =>
      (interp k ρ a).bind fun v =>
      (interp k ρ b).bind fun w =>
      match v with
      | .closure f x _ body captured =>
          interp k ((x, w) :: (f, v) :: captured) body
      | .const _ => .stuck

inductive HasType : Context → Expr → Ty → Prop where
  | const : HasType Γ (.const c) c.type
  | var : lookup x Γ = .value A → HasType Γ (.var x) A
  | bin : Delta o A B = some C → HasType Γ a A → HasType Γ b B →
      HasType Γ (.bin o a b) C
  | fn : HasType ((x, A) :: (f, .fn A B) :: Γ) body B →
      HasType Γ (.fn f x A body) (.fn A B)
  | app : HasType Γ a (.fn A B) → HasType Γ b A → HasType Γ (.app a b) B

mutual
  inductive ValueTyped : Value → Ty → Prop where
    | int : ValueTyped (.const (.int n)) .int
    | bool : ValueTyped (.const (.bool b)) .bool
    | closure : EnvTyped Γ ρ →
        HasType ((x, A) :: (f, .fn A B) :: Γ) body B →
        ValueTyped (.closure f x A body ρ) (.fn A B)

  inductive EnvTyped : Context → Env → Prop where
    | nil : EnvTyped [] []
    | cons : ValueTyped v A → EnvTyped Γ ρ →
        EnvTyped ((x, A) :: Γ) ((x, v) :: ρ)
end

theorem ValueTyped.const {c : Const} : ValueTyped (.const c) c.type := by
  cases c with
  | int => exact .int
  | bool => exact .bool

inductive ResultTyped : Result Value → Ty → Prop where
  | value : ValueTyped v A → ResultTyped (.value v) A
  | timeout : ResultTyped .timeout A

/-! The three safety lemmas. -/

theorem delta_safe (hδ : Delta o A B = some C)
    (hv : ValueTyped v A) (hw : ValueTyped w B) :
    ∃ u, delta o v w = .value u ∧ ValueTyped u C := by
  cases A <;> cases B <;> simp only [Delta, reduceCtorEq] at hδ
  cases hδ
  cases hv
  cases hw
  cases o <;> exact ⟨_, rfl, ValueTyped.const⟩

theorem lookup_safe (hρ : EnvTyped Γ ρ) (hx : lookup x Γ = .value A) :
    ∃ v, lookup x ρ = .value v ∧ ValueTyped v A := by
  induction Γ generalizing ρ with
  | nil => cases hρ; cases hx
  | cons entry Γ ih =>
    cases hρ with
    | @cons v B _ ρ y hv hρ =>
      by_cases hxy : x = y
      · simp only [lookup, hxy, ↓reduceIte] at hx ⊢
        cases hx
        exact ⟨v, rfl, hv⟩
      · simp only [lookup, hxy, ↓reduceIte] at hx ⊢
        exact ih hρ hx

private theorem bind_safe (hr : ResultTyped r A)
    (hf : ∀ v, ValueTyped v A → ResultTyped (f v) B) :
    ResultTyped (r.bind f) B := by
  cases hr with
  | value hv => exact hf _ hv
  | timeout => exact .timeout

theorem interp_safe (he : HasType Γ e A) (hρ : EnvTyped Γ ρ) (k : Nat) :
    ResultTyped (interp k ρ e) A := by
  induction k generalizing Γ ρ e A with
  | zero => exact .timeout
  | succ k ih =>
    cases he with
    | const => exact .value .const
    | var hx =>
      obtain ⟨v, hv, ht⟩ := lookup_safe hρ hx
      change ResultTyped (lookup _ _) _
      rw [hv]
      exact .value ht
    | fn hb => exact .value (.closure hρ hb)
    | bin hδ ha hb =>
      apply bind_safe (ih ha hρ)
      intro v hv
      apply bind_safe (ih hb hρ)
      intro w hw
      obtain ⟨u, hu, ht⟩ := delta_safe hδ hv hw
      rw [hu]
      exact .value ht
    | app ha hb =>
      apply bind_safe (ih ha hρ)
      intro v hv
      apply bind_safe (ih hb hρ)
      intro w hw
      cases hv with
      | closure hc hbody =>
        exact ih hbody (.cons hw (.cons (.closure hc hbody) hc))

theorem no_stuck (he : HasType Γ e A) (hρ : EnvTyped Γ ρ) (k : Nat) :
    interp k ρ e ≠ .stuck := by
  intro h
  have hs := interp_safe he hρ k
  rw [h] at hs
  cases hs

/-! All non-timeout results are stable, including stuck results of untyped terms. -/

def Result.Refines (r s : Result α) : Prop := r ≠ .timeout → s = r

private theorem bind_refines {r s : Result α} {f g : α → Result β}
    (h : r.Refines s) (hf : ∀ v, (f v).Refines (g v)) :
    (r.bind f).Refines (s.bind g) := by
  intro hn
  cases r with
  | timeout => exact False.elim (hn rfl)
  | stuck =>
    have hs := h (by intro h'; cases h')
    rw [hs]
    rfl
  | value v =>
    have hs := h (by intro h'; cases h')
    rw [hs]
    exact hf v hn

theorem interp_step (k : Nat) (ρ : Env) (e : Expr) :
    (interp k ρ e).Refines (interp (k + 1) ρ e) := by
  induction k generalizing ρ e with
  | zero => intro h; exact False.elim (h rfl)
  | succ k ih =>
    cases e with
    | const c => intro _; rfl
    | var x => intro _; rfl
    | fn f x A body => intro _; rfl
    | bin o a b =>
      apply bind_refines (ih ρ a)
      intro v
      apply bind_refines (ih ρ b)
      intro w _
      rfl
    | app a b =>
      apply bind_refines (ih ρ a)
      intro v
      apply bind_refines (ih ρ b)
      intro w
      cases v with
      | const c => intro _; rfl
      | closure f x A body captured => exact ih _ body

theorem interp_stable (hkl : k ≤ l) (h : interp k ρ e ≠ .timeout) :
    interp l ρ e = interp k ρ e := by
  induction hkl with
  | refl => rfl
  | @step l hkl ih =>
    have hl : interp l ρ e ≠ .timeout := by rw [ih]; exact h
    exact (interp_step l ρ e hl).trans ih

/-! Constructive whole-program observations: propositions, not a termination decider. -/

def Returns (ρ : Env) (e : Expr) (v : Value) : Prop :=
  ∃ k, interp k ρ e = .value v

def Diverges (ρ : Env) (e : Expr) : Prop :=
  ∀ k, interp k ρ e = .timeout

def GoesWrong (ρ : Env) (e : Expr) : Prop :=
  ∃ k, interp k ρ e = .stuck

theorem returns_typed (he : HasType Γ e A) (hρ : EnvTyped Γ ρ)
    (hv : Returns ρ e v) : ValueTyped v A := by
  obtain ⟨k, hk⟩ := hv
  have hs := interp_safe he hρ k
  rw [hk] at hs
  cases hs with
  | value ht => exact ht

theorem returns_unique (hv : Returns ρ e v) (hw : Returns ρ e w) : v = w := by
  obtain ⟨k, hk⟩ := hv
  obtain ⟨l, hl⟩ := hw
  have hn : interp k ρ e ≠ .timeout := by rw [hk]; intro h; cases h
  have hm : interp l ρ e ≠ .timeout := by rw [hl]; intro h; cases h
  have hkv := interp_stable (Nat.le_max_left k l) hn
  have hlw := interp_stable (Nat.le_max_right k l) hm
  rw [hk] at hkv
  rw [hl] at hlw
  exact Result.value.inj (hkv.symm.trans hlw)

theorem never_goes_wrong (he : HasType Γ e A) (hρ : EnvTyped Γ ρ) :
    ¬ GoesWrong ρ e := by
  rintro ⟨k, hk⟩
  exact no_stuck he hρ k hk

theorem diverges_iff_no_return (he : HasType Γ e A) (hρ : EnvTyped Γ ρ) :
    Diverges ρ e ↔ ∀ v, ¬ Returns ρ e v := by
  constructor
  · intro hd v hv
    obtain ⟨k, hk⟩ := hv
    have ht := hd k
    rw [hk] at ht
    cases ht
  · intro hn k
    cases hk : interp k ρ e with
    | timeout => rfl
    | stuck => exact False.elim (no_stuck he hρ k hk)
    | value v => exact False.elim (hn v ⟨k, hk⟩)

theorem returns_int (he : HasType Γ e .int) (hρ : EnvTyped Γ ρ)
    (hv : Returns ρ e v) : ∃ n, v = .const (.int n) := by
  cases returns_typed he hρ hv with
  | int => exact ⟨_, rfl⟩

theorem returns_bool (he : HasType Γ e .bool) (hρ : EnvTyped Γ ρ)
    (hv : Returns ρ e v) : ∃ b, v = .const (.bool b) := by
  cases returns_typed he hρ hv with
  | bool => exact ⟨_, rfl⟩

/-! Checked examples, including genuine recursive divergence. -/

def arithmetic : Expr :=
  .bin .eq (.bin .sub (.bin .add (.const (.int 40)) (.const (.int 3)))
    (.const (.int 1))) (.const (.int 42))

theorem arithmetic_typed : HasType [] arithmetic .bool :=
  .bin rfl (.bin rfl (.bin rfl .const .const) .const) .const

theorem arithmetic_returns : interp 4 [] arithmetic = .value (.const (.bool true)) := rfl

-- The argument shadows self even when the two binder names coincide.
def shadowing : Expr := .app (.fn "f" "f" .int (.var "f")) (.const (.int 7))

theorem shadowing_typed : HasType [] shadowing .int :=
  .app (.fn (.var rfl)) .const

theorem shadowing_returns : interp 2 [] shadowing = .value (.const (.int 7)) := rfl

def loopBody : Expr := .app (.var "f") (.var "x")
def loopFn : Expr := .fn "f" "x" .int loopBody
def loop : Expr := .app loopFn (.const (.int 0))
def loopClosure : Value := .closure "f" "x" .int loopBody []
def loopEnv : Env := [("x", .const (.int 0)), ("f", loopClosure)]

theorem loop_typed : HasType [] loop .int :=
  .app (.fn (.app (.var rfl) (.var rfl))) .const

theorem loopBody_timeout (k : Nat) : interp k loopEnv loopBody = .timeout := by
  induction k with
  | zero => rfl
  | succ k ih =>
    cases k with
    | zero => rfl
    | succ n => exact ih

theorem loop_timeout (k : Nat) : interp k [] loop = .timeout := by
  cases k with
  | zero => rfl
  | succ k =>
    cases k with
    | zero => rfl
    | succ n => exact loopBody_timeout (n + 1)

theorem loop_diverges : Diverges [] loop := loop_timeout

end Recursive
