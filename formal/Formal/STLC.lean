import Std

/-!
A direct, constructive translation of EvalSTLC.thy. In particular, `Int`
constants contain naturals, lambdas are nonrecursive, environments are
association lists, and application evaluates its argument before checking
whether its operator is a closure. See ../STLC.md for source correspondence.
-/

namespace STLC

inductive Result (α : Type) where
  | result : α → Result α
  | stuck : Result α
  | timeout : Result α
  deriving Repr, DecidableEq

def result_bind (r : Result α) (f : α → Result β) : Result β :=
  match r with
  | .result a => f a
  | .stuck => .stuck
  | .timeout => .timeout

def «return» (a : α) : Result α := .result a
def stuck : Result α := .stuck
def timeout : Result α := .timeout

abbrev Info := Nat
abbrev Name := Nat

inductive Ty where
  | int
  | bool
  | arrow : Ty → Ty → Ty
  deriving Repr, DecidableEq

inductive Const where
  | int : Info → Nat → Const
  | bool : Info → Bool → Const
  deriving Repr, DecidableEq

inductive PrimOp where
  | succ : Info → PrimOp
  | pred : Info → PrimOp
  | isZero : Info → PrimOp
  deriving Repr, DecidableEq

inductive Expr where
  | var : Info → Name → Expr
  | const : Info → Const → Expr
  | lam : Info → Name → Ty → Expr → Expr
  | app : Info → Expr → Expr → Expr
  | primApp : Info → PrimOp → Expr → Expr
  | ifE : Info → Expr → Expr → Expr → Expr
  deriving Repr, DecidableEq

inductive Val where
  | const : Info → Const → Val
  | closure : Info → Name → Ty → Expr → List (Name × Val) → Val
  deriving Repr

abbrev Env := List (Name × Val)

def lookup [DecidableEq α] : List (α × β) → α → Result β
  | [], _ => .stuck
  | (y, v) :: rest, x => if x = y then .result v else lookup rest x

def to_int : Val → Result Nat
  | .const _ (.int _ n) => .result n
  | .const _ (.bool _ _) => .stuck
  | .closure _ _ _ _ _ => .stuck

def to_bool : Val → Result Bool
  | .const _ (.bool _ b) => .result b
  | .const _ (.int _ _) => .stuck
  | .closure _ _ _ _ _ => .stuck

def to_closure : Val → Result (Name × Expr × Env)
  | .const _ _ => .stuck
  | .closure _ x _ e ρ => .result (x, e, ρ)

def from_int (n : Nat) (i : Info) : Result Val :=
  .result (.const i (.int i n))

def from_bool (b : Bool) (i : Info) : Result Val :=
  .result (.const i (.bool i b))

def delta : PrimOp → Val → Result Val
  | .succ i, v => result_bind (to_int v) (fun n => from_int (n + 1) i)
  | .pred i, v => result_bind (to_int v) (fun n => from_int (n - 1) i)
  | .isZero i, v => result_bind (to_int v) (fun n => from_bool (n == 0) i)

/-- Fuel bounds recursion depth: each recursive call receives the same predecessor. -/
def interp : Expr → Env → Nat → Result Val
  | _, _, 0 => .timeout
  | .var _ x, ρ, _ + 1 => lookup ρ x
  | .const i c, _, _ + 1 => .result (.const i c)
  | .lam i x t e, ρ, _ + 1 => .result (.closure i x t e ρ)
  | .primApp _ op e, ρ, k + 1 =>
      result_bind (interp e ρ k) (delta op)
  | .app _ e₁ e₂, ρ, k + 1 =>
      result_bind (interp e₁ ρ k) fun v₁ =>
      result_bind (interp e₂ ρ k) fun v₂ =>
      result_bind (to_closure v₁) fun (x, e, ρ') =>
      interp e ((x, v₂) :: ρ') k
  | .ifE _ e₁ e₂ e₃, ρ, k + 1 =>
      result_bind (interp e₁ ρ k) fun v =>
      result_bind (to_bool v) fun b =>
      if b then interp e₂ ρ k else interp e₃ ρ k

inductive Observable where
  | const : Const → Observable
  | diverge
  deriving Repr, DecidableEq

/-- Exactly the source observation relation; closures and stuck runs are unobserved. -/
inductive Eval : Expr → Observable → Prop where
  | evalc {e k i c} : interp e [] k = .result (.const i c) → Eval e (.const c)
  | evald {e} : (∀ k, interp e [] k = .timeout) → Eval e .diverge

abbrev TyEnv := List (Name × Ty)

def typeof : Const → Ty
  | .int _ _ => .int
  | .bool _ _ => .bool

def typeof_op : PrimOp → Ty
  | .succ _ => .arrow .int .int
  | .pred _ => .arrow .int .int
  | .isZero _ => .arrow .int .bool

inductive WtExpr : TyEnv → Expr → Ty → Prop where
  | var {Γ x t i} : lookup Γ x = .result t → WtExpr Γ (.var i x) t
  | const {c t Γ i} : typeof c = t → WtExpr Γ (.const i c) t
  | lam {x t Γ e rt i} :
      WtExpr ((x, t) :: Γ) e rt → WtExpr Γ (.lam i x t e) (.arrow t rt)
  | primApp {op t₁ t₂ Γ e i} :
      typeof_op op = .arrow t₁ t₂ → WtExpr Γ e t₁ →
      WtExpr Γ (.primApp i op e) t₂
  | app {Γ e₁ t₁ t₂ e₂ i} :
      WtExpr Γ e₁ (.arrow t₁ t₂) → WtExpr Γ e₂ t₁ →
      WtExpr Γ (.app i e₁ e₂) t₂
  | ifE {Γ e₁ e₂ t e₃ i} :
      WtExpr Γ e₁ .bool → WtExpr Γ e₂ t → WtExpr Γ e₃ t →
      WtExpr Γ (.ifE i e₁ e₂ e₃) t

mutual
  inductive WtValue : Val → Ty → Prop where
    | const {c t i} : typeof c = t → WtValue (.const i c) t
    | closure {x t₁ Γ e t₂ ρ i} :
        WtExpr ((x, t₁) :: Γ) e t₂ → WtEnv Γ ρ →
        WtValue (.closure i x t₁ e ρ) (.arrow t₁ t₂)

  inductive WtEnv : TyEnv → Env → Prop where
    | nil : WtEnv [] []
    | cons {v t Γ ρ x} :
        WtValue v t → WtEnv Γ ρ → WtEnv ((x, t) :: Γ) ((x, v) :: ρ)
end

inductive WtResult : Result Val → Ty → Prop where
  | result {v t} : WtValue v t → WtResult (.result v) t
  | timeout {t} : WtResult .timeout t

theorem typeof_bool {c : Const} {P : Prop} (h : typeof c = .bool)
    (hP : ∀ i b, c = .bool i b → P) : P := by
  cases c with
  | int i n => cases h
  | bool i b => exact hP i b rfl

theorem typeof_fun {c : Const} {a b : Ty} {P : Prop}
    (h : typeof c = .arrow a b) : P := by
  cases c <;> cases h

theorem int_value {v : Val} (h : WtValue v .int) :
    ∃ i j n, v = .const i (.int j n) := by
  cases h with
  | @const c _ i hc =>
      cases c with
      | int j n => exact ⟨i, j, n, rfl⟩
      | bool j b => cases hc

theorem bool_value {v : Val} (h : WtValue v .bool) :
    ∃ i j b, v = .const i (.bool j b) := by
  cases h with
  | @const c _ i hc =>
      cases c with
      | int j n => cases hc
      | bool j b => exact ⟨i, j, b, rfl⟩

theorem fun_value {v : Val} {a b : Ty} (h : WtValue v (.arrow a b)) :
    ∃ i x e ρ Γ, v = .closure i x a e ρ ∧
      WtExpr ((x, a) :: Γ) e b ∧ WtEnv Γ ρ := by
  cases h with
  | const hc => exact typeof_fun hc
  | closure he hρ => exact ⟨_, _, _, _, _, rfl, he, hρ⟩

theorem wt_bind {r : Result Val} {a b : Ty} {f : Val → Result Val}
    (hr : WtResult r a)
    (hf : ∀ v, WtValue v a → WtResult (f v) b) :
    WtResult (result_bind r f) b := by
  cases hr with
  | result hv => exact hf _ hv
  | timeout => exact .timeout

theorem delta_safe {f : PrimOp} {a b : Ty} {v : Val}
    (hop : typeof_op f = .arrow a b) (hv : WtValue v a) :
    WtResult (delta f v) b := by
  cases f <;> cases hop
  all_goals obtain ⟨i, j, n, rfl⟩ := int_value hv
  all_goals exact .result (.const rfl)

theorem lookup_safe {Γ : TyEnv} {ρ : Env} {x : Name} {a : Ty}
    (hρ : WtEnv Γ ρ) (hl : lookup Γ x = .result a) :
    WtResult (lookup ρ x) a := by
  induction Γ generalizing ρ with
  | nil =>
      cases hρ
      cases hl
  | cons entry Γ ih =>
      obtain ⟨y, t⟩ := entry
      cases hρ with
      | cons hv hρ =>
          by_cases hxy : x = y
          · simp only [lookup, if_pos hxy] at hl ⊢
            cases hl
            exact .result hv
          · simp only [lookup, if_neg hxy] at hl ⊢
            exact ih hρ hl

theorem interp_safe {Γ : TyEnv} {e : Expr} {a : Ty} {ρ : Env}
    (he : WtExpr Γ e a) (hρ : WtEnv Γ ρ) (k : Nat) :
    WtResult (interp e ρ k) a := by
  induction k generalizing Γ e a ρ with
  | zero => exact .timeout
  | succ k ih =>
      cases he with
      | var hl => exact lookup_safe hρ hl
      | const hc => exact .result (.const hc)
      | lam hb => exact .result (.closure hb hρ)
      | primApp hop he =>
          exact wt_bind (ih he hρ) (fun _ hv => delta_safe hop hv)
      | app he₁ he₂ =>
          apply wt_bind (ih he₁ hρ)
          intro v₁ hv₁
          apply wt_bind (ih he₂ hρ)
          intro v₂ hv₂
          obtain ⟨i, x, body, ρ', Γ', rfl, hb, hρ'⟩ := fun_value hv₁
          exact ih hb (.cons hv₂ hρ')
      | ifE hc ht hf =>
          apply wt_bind (ih hc hρ)
          intro v hv
          obtain ⟨i, j, b, rfl⟩ := bool_value hv
          cases b with
          | false => exact ih hf hρ
          | true => exact ih ht hρ

/-- Finite-fuel safety holds for open terms in any matching typed environment. -/
theorem no_stuck {Γ : TyEnv} {e : Expr} {a : Ty} {ρ : Env}
    (he : WtExpr Γ e a) (hρ : WtEnv Γ ρ) (k : Nat) :
    interp e ρ k ≠ .stuck := by
  intro h
  have hs := interp_safe he hρ k
  rw [h] at hs
  cases hs

theorem closed_no_stuck {e : Expr} {a : Ty} (he : WtExpr [] e a) (k : Nat) :
    interp e [] k ≠ .stuck := no_stuck he .nil k

/-- The flat information order: only timeout can change when fuel increases. -/
def Result.Refines (r s : Result α) : Prop := r = .timeout ∨ r = s

theorem result_bind_mono {r s : Result α} {f g : α → Result β}
    (h : Result.Refines r s) (hf : ∀ x, Result.Refines (f x) (g x)) :
    Result.Refines (result_bind r f) (result_bind s g) := by
  rcases h with h | h
  · subst r
    exact Or.inl rfl
  · subst s
    cases r with
    | result x => exact hf x
    | stuck => exact Or.inr rfl
    | timeout => exact Or.inl rfl

/-- Fuel monotonicity also covers ill-typed terms and their stuck outcomes. -/
theorem interp_mono (e : Expr) (ρ : Env) {k l : Nat} (h : k ≤ l) :
    Result.Refines (interp e ρ k) (interp e ρ l) := by
  induction l generalizing k e ρ with
  | zero =>
      have hk : k = 0 := Nat.eq_zero_of_le_zero h
      subst k
      exact Or.inr rfl
  | succ l ih =>
      cases k with
      | zero => exact Or.inl rfl
      | succ k =>
          have hkl : k ≤ l := Nat.le_of_succ_le_succ h
          cases e with
          | var i x => exact Or.inr rfl
          | const i c => exact Or.inr rfl
          | lam i x t body => exact Or.inr rfl
          | primApp i op e =>
              exact result_bind_mono (ih e ρ hkl) (fun _ => Or.inr rfl)
          | app i e₁ e₂ =>
              apply result_bind_mono (ih e₁ ρ hkl)
              intro v₁
              apply result_bind_mono (ih e₂ ρ hkl)
              intro v₂
              apply result_bind_mono (Or.inr rfl)
              intro closure
              exact ih closure.2.1 ((closure.1, v₂) :: closure.2.2) hkl
          | ifE i e₁ e₂ e₃ =>
              apply result_bind_mono (ih e₁ ρ hkl)
              intro v
              apply result_bind_mono (Or.inr rfl)
              intro b
              cases b with
              | false => exact ih e₃ ρ hkl
              | true => exact ih e₂ ρ hkl

/-- Every settled result (success or stuck) is unchanged at greater fuel. -/
theorem interp_stable {e : Expr} {ρ : Env} {k l : Nat}
    (hkl : k ≤ l) (h : interp e ρ k ≠ .timeout) :
    interp e ρ l = interp e ρ k := by
  rcases interp_mono e ρ hkl with ht | he
  · exact False.elim (h ht)
  · exact he.symm

theorem interp_result_stable {e : Expr} {ρ : Env} {k l : Nat} {v : Val}
    (hkl : k ≤ l) (h : interp e ρ k = .result v) :
    interp e ρ l = .result v := by
  rcases interp_mono e ρ hkl with ht | he
  · rw [h] at ht
    cases ht
  · exact he.symm.trans h

theorem interp_stuck_stable {e : Expr} {ρ : Env} {k l : Nat}
    (hkl : k ≤ l) (h : interp e ρ k = .stuck) :
    interp e ρ l = .stuck := by
  rcases interp_mono e ρ hkl with ht | he
  · rw [h] at ht
    cases ht
  · exact he.symm.trans h

/-- Any two settled finite observations agree, without choosing an infinite run. -/
theorem interp_coherent {e : Expr} {ρ : Env} {k l : Nat}
    (hk : interp e ρ k ≠ .timeout) (hl : interp e ρ l ≠ .timeout) :
    interp e ρ k = interp e ρ l := by
  rcases Nat.le_total k l with hkl | hlk
  · exact (interp_stable hkl hk).symm
  · exact interp_stable hlk hl

namespace Examples

def identity : Expr := .lam 10 0 .int (.var 11 0)
def fortyOne : Expr := .const 20 (.int 21 41)
def answer : Expr := .primApp 30 (.succ 31) (.app 32 identity fortyOne)

example : WtExpr [] answer .int :=
  .primApp rfl (.app (.lam (.var rfl)) (.const rfl))

-- Primitive results use the operator's info for both the value and constant.
example : interp answer [] 4 = .result (.const 31 (.int 31 42)) := rfl
example : interp (.primApp 1 (.pred 2) (.const 3 (.int 4 0))) [] 2 =
    .result (.const 2 (.int 2 0)) := rfl

-- Association lists preserve shadowing; the first matching entry wins.
example : lookup [(0, Ty.bool), (0, Ty.int)] 0 = .result .bool := rfl

-- A lambda captures its environment and does not bind itself recursively.
example : interp identity [(9, .const 1 (.int 2 7))] 1 =
    .result (.closure 10 0 .int (.var 11 0) [(9, .const 1 (.int 2 7))]) := rfl

-- Checking the nonfunction operator BEFORE evaluating the argument would be
-- wrong: at this fuel the source returns timeout, not stuck.
def badApplication : Expr :=
  .app 0 fortyOne (.primApp 1 (.succ 2) fortyOne)

example : interp badApplication [] 2 = .timeout := rfl
example : interp badApplication [] 3 = .stuck := rfl

-- Only the selected branch is evaluated.
example : interp (.ifE 0 (.const 1 (.bool 2 true)) fortyOne (.var 3 99)) [] 2 =
    .result (.const 20 (.int 21 41)) := rfl

#eval interp answer [] 4
#eval interp (.primApp 1 (.pred 2) (.const 3 (.int 4 0))) [] 2
#eval interp badApplication [] 2
#eval interp badApplication [] 3

end Examples

end STLC
