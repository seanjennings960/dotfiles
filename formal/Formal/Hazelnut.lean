import Std

/-! Core Hazelnut statics and a deterministic, executable expression editor.
See EDITOR.md for rule correspondence and the precise action-subset boundary. -/
namespace Hazelnut

inductive Ty where
  | hole | num | arr (domain codomain : Ty)
  deriving Repr, DecidableEq, BEq

inductive Expr where
  | hole
  | nonempty (inside : Expr)
  | var (name : String)
  | lit (value : Nat)
  | lam (name : String) (body : Expr)
  | app (fn arg : Expr)
  | plus (left right : Expr)
  | asc (term : Expr) (type : Ty)
  deriving Repr, DecidableEq, BEq

/- A structural measure independent of String's library size implementation. -/
def Expr.nodes : Expr → Nat
  | .hole | .var _ | .lit _ => 1
  | .nonempty e | .lam _ e | .asc e _ => 1 + e.nodes
  | .app f a | .plus f a => 1 + f.nodes + a.nodes

abbrev Ctx := List (String × Ty)

def lookup (Γ : Ctx) (x : String) : Option Ty :=
  match Γ with
  | [] => none
  | (y, t) :: rest => if x = y then some t else lookup rest x

def consistent : Ty → Ty → Bool
  | .hole, _ | _, .hole => true
  | .num, .num => true
  | .arr a b, .arr c d => consistent a c && consistent b d
  | _, _ => false

inductive Consistent : Ty → Ty → Prop where
  | holeL : Consistent .hole t
  | holeR : Consistent t .hole
  | num : Consistent .num .num
  | arr : Consistent a c → Consistent b d → Consistent (.arr a b) (.arr c d)

theorem Consistent.refl (t : Ty) : Consistent t t := by
  induction t with
  | hole => exact .holeL
  | num => exact .num
  | arr _ _ ia ib => exact .arr ia ib

theorem Consistent.symm (h : Consistent a b) : Consistent b a := by
  induction h with
  | holeL => exact .holeR
  | holeR => exact .holeL
  | num => exact .num
  | arr _ _ ia ib => exact .arr ia ib

theorem consistent_sound {a b} (h : consistent a b = true) : Consistent a b := by
  induction a generalizing b with
  | hole => exact .holeL
  | num =>
    cases b with
    | hole => exact .holeR
    | num => exact .num
    | arr _ _ => simp [consistent] at h
  | arr a c ia ic =>
    cases b with
    | hole => exact .holeR
    | num => simp [consistent] at h
    | arr b d =>
      exact .arr (ia (Bool.and_eq_true_iff.mp h).1) (ic (Bool.and_eq_true_iff.mp h).2)

def matchArrow : Ty → Option (Ty × Ty)
  | .hole => some (.hole, .hole)
  | .arr a b => some (a, b)
  | .num => none

mutual
  inductive Synth : Ctx → Expr → Ty → Prop where
    | asc : Check Γ e t → Synth Γ (.asc e t) t
    | var : lookup Γ x = some t → Synth Γ (.var x) t
    | app : Synth Γ f t → matchArrow t = some (a, b) → Check Γ e a →
        Synth Γ (.app f e) b
    | lit : Synth Γ (.lit n) .num
    | plus : Check Γ l .num → Check Γ r .num → Synth Γ (.plus l r) .num
    | hole : Synth Γ .hole .hole
    | nonempty : Synth Γ e t → Synth Γ (.nonempty e) .hole
  inductive Check : Ctx → Expr → Ty → Prop where
    | sub : Synth Γ e a → Consistent a b → Check Γ e b
    | lam : matchArrow t = some (a, b) → Check ((x, a) :: Γ) e b →
        Check Γ (.lam x e) t
end

/- A structural recursion computes both modes together. A bare lambda has no
synthetic rule. In particular, a nonempty hole checks its interior. -/
def typing (Γ : Ctx) : Expr → Option Ty × (Ty → Bool)
  | .lam x e => (none, fun t => match matchArrow t with
      | none => false
      | some (a, b) => (typing ((x, a) :: Γ) e).2 b)
  | e =>
    let s := match e with
      | .hole => some Ty.hole
      | .lam _ _ => none
      | .var x => lookup Γ x
      | .lit _ => some Ty.num
      | .nonempty e => (typing Γ e).1.map (fun _ => Ty.hole)
      | .asc e t => if (typing Γ e).2 t then some t else none
      | .app f a => do
          let ft ← (typing Γ f).1
          let (dom, cod) ← matchArrow ft
          if (typing Γ a).2 dom then some cod else none
      | .plus l r => if (typing Γ l).2 .num && (typing Γ r).2 .num then
          some Ty.num else none
    (s, fun t => match s with
      | some u => consistent u t
      | none => false)

def synth (Γ : Ctx) (e : Expr) : Option Ty := (typing Γ e).1
def check (Γ : Ctx) (e : Expr) (t : Ty) : Bool := (typing Γ e).2 t

theorem typing_sound (e : Expr) (Γ : Ctx) :
    (∀ t, synth Γ e = some t → Synth Γ e t) ∧
    (∀ t, check Γ e t = true → Check Γ e t) := by
  induction e generalizing Γ with
  | lam x e ih =>
    constructor
    · simp [synth, typing]
    · intro t h
      cases hm : matchArrow t with
      | none => simp [check, typing, hm] at h
      | some ab =>
        rcases ab with ⟨a, b⟩
        exact .lam hm ((ih ((x, a) :: Γ)).2 b (by simpa [check, typing, hm] using h))
  | hole =>
    constructor
    · intro t h; simp [synth, typing] at h; subst t; exact .hole
    · intro t _; exact .sub .hole .holeL
  | var x =>
    constructor
    · intro t h; exact .var h
    · intro t h
      cases hs : lookup Γ x with
      | none => simp [check, typing, hs] at h
      | some u => exact .sub (.var hs) (consistent_sound (by simpa [check, typing, hs] using h))
  | lit n =>
    constructor
    · intro t h; simp [synth, typing] at h; subst t; exact .lit
    · intro t h; exact .sub .lit (consistent_sound h)
  | nonempty e ih =>
    have s : ∀ t, synth Γ (.nonempty e) = some t → Synth Γ (.nonempty e) t := by
      intro t h
      cases hs : (typing Γ e).1 with
      | none => simp [synth, typing, hs] at h
      | some u =>
        have ht : t = .hole := by simpa [synth, typing, hs] using h.symm
        subst t; exact .nonempty ((ih Γ).1 u hs)
    constructor
    · exact s
    · intro t h
      cases hs : (typing Γ e).1 with
      | none => simp [check, typing, hs] at h
      | some u => exact .sub (.nonempty ((ih Γ).1 u hs)) .holeL
  | asc e a ih =>
    have s : ∀ t, synth Γ (.asc e a) = some t → Synth Γ (.asc e a) t := by
      intro t h
      simp only [synth, typing] at h
      split at h
      next hc => cases h; exact .asc ((ih Γ).2 a hc)
      next => contradiction
    constructor
    · exact s
    · intro t h
      cases hc : (typing Γ e).2 a <;> simp [check, typing, hc] at h
      exact .sub (.asc ((ih Γ).2 a hc)) (consistent_sound h)
  | plus l r il ir =>
    have s : ∀ t, synth Γ (.plus l r) = some t → Synth Γ (.plus l r) t := by
      intro t h
      simp only [synth, typing] at h
      split at h
      next hc =>
        cases h
        exact .plus ((il Γ).2 .num (Bool.and_eq_true_iff.mp hc).1)
          ((ir Γ).2 .num (Bool.and_eq_true_iff.mp hc).2)
      next => contradiction
    constructor
    · exact s
    · intro t h
      cases hl : (typing Γ l).2 .num <;> cases hr : (typing Γ r).2 .num <;>
        simp [check, typing, hl, hr] at h
      exact .sub (.plus ((il Γ).2 .num hl) ((ir Γ).2 .num hr)) (consistent_sound h)
  | app f e iff ie =>
    have s : ∀ t, synth Γ (.app f e) = some t → Synth Γ (.app f e) t := by
      intro t h
      cases hf : (typing Γ f).1 with
      | none => simp [synth, typing, hf] at h
      | some ft =>
        cases hm : matchArrow ft with
        | none => simp [synth, typing, hf, hm] at h
        | some ab =>
          rcases ab with ⟨a, b⟩
          cases hc : (typing Γ e).2 a <;> simp [synth, typing, hf, hm, hc] at h
          subst t
          exact .app ((iff Γ).1 ft hf) hm ((ie Γ).2 a hc)
    constructor
    · exact s
    · intro t h
      cases hf : (typing Γ f).1 with
      | none => simp [check, typing, hf] at h
      | some ft =>
        cases hm : matchArrow ft with
        | none => simp [check, typing, hf, hm] at h
        | some ab =>
          rcases ab with ⟨a, b⟩
          cases hc : (typing Γ e).2 a <;> simp [check, typing, hf, hm, hc] at h
          exact .sub (.app ((iff Γ).1 ft hf) hm ((ie Γ).2 a hc)) (consistent_sound h)

theorem synth_sound (h : synth Γ e = some t) : Synth Γ e t := (typing_sound e Γ).1 t h
theorem check_sound (h : check Γ e t = true) : Check Γ e t := (typing_sound e Γ).2 t h

theorem consistent_complete (h : Consistent a b) : consistent a b = true := by
  induction h with
  | holeL => rfl
  | @holeR t => cases t <;> rfl
  | num => rfl
  | arr _ _ ia ib => simp [consistent, ia, ib]

theorem check_of_synth (hs : synth Γ e = some a) (hc : consistent a b = true) :
    check Γ e b = true := by
  cases e <;> simp only [synth, typing] at hs <;> simp only [check, typing]
  all_goals first | (rw [hs]; exact hc) | (cases hs <;> exact hc)

mutual
  theorem synth_complete (h : Synth Γ e t) : synth Γ e = some t := by
    cases h with
    | hole => rfl
    | lit => rfl
    | var h => exact h
    | asc h => simp [synth, typing, show (typing Γ _).2 t = true from check_complete h]
    | nonempty h => simp [synth, typing, show (typing Γ _).1 = _ from synth_complete h]
    | plus hl hr =>
      simp [synth, typing, show (typing Γ _).2 .num = true from check_complete hl,
        show (typing Γ _).2 .num = true from check_complete hr]
    | app hf hm ha =>
      simp [synth, typing, show (typing Γ _).1 = _ from synth_complete hf, hm,
        show (typing Γ _).2 _ = true from check_complete ha]
  termination_by e.nodes * 2
  decreasing_by all_goals simp_all only [Expr.nodes] <;> omega

  theorem check_complete (h : Check Γ e t) : check Γ e t = true := by
    cases h with
    | sub hs hc => exact check_of_synth (synth_complete hs) (consistent_complete hc)
    | lam hm hb => simp [check, typing, hm,
        show (typing (_ :: Γ) _).2 _ = true from check_complete hb]
  termination_by e.nodes * 2 + 1
  decreasing_by all_goals simp_all only [Expr.nodes] <;> omega
end

theorem synth_iff : synth Γ e = some t ↔ Synth Γ e t := ⟨synth_sound, synth_complete⟩
theorem check_iff : check Γ e t = true ↔ Check Γ e t := ⟨check_sound, check_complete⟩

theorem synthesis_unique (h : Synth Γ e a) (h' : Synth Γ e b) : a = b :=
  Option.some.inj ((synth_complete h).symm.trans (synth_complete h'))

inductive Child where
  | first | second
  deriving Repr, DecidableEq, BEq

inductive Direction where
  | parent | child (which : Child)
  deriving Repr, DecidableEq, BEq

inductive Frame where
  | lam (name : String)
  | appL (arg : Expr) | appR (fn : Expr)
  | plusL (right : Expr) | plusR (left : Expr)
  | asc (type : Ty) | nonempty
  deriving Repr, DecidableEq, BEq

def Frame.plug : Frame → Expr → Expr
  | .lam x, e => .lam x e
  | .appL a, e => .app e a
  | .appR f, e => .app f e
  | .plusL r, e => .plus e r
  | .plusR l, e => .plus l e
  | .asc t, e => .asc e t
  | .nonempty, e => .nonempty e

structure ZExpr where
  focus : Expr
  path : List Frame := []
  deriving Repr, DecidableEq, BEq

def ZExpr.erase (z : ZExpr) : Expr := z.path.foldl (fun e f => f.plug e) z.focus

def move (d : Direction) (z : ZExpr) : Option ZExpr :=
  match d with
  | .parent => match z.path with
      | [] => none
      | f :: fs => some ⟨f.plug z.focus, fs⟩
  | .child c => match z.focus, c with
      | .lam x e, .first => some ⟨e, .lam x :: z.path⟩
      | .nonempty e, .first => some ⟨e, .nonempty :: z.path⟩
      | .asc e t, .first => some ⟨e, .asc t :: z.path⟩
      | .app f a, .first => some ⟨f, .appL a :: z.path⟩
      | .app f a, .second => some ⟨a, .appR f :: z.path⟩
      | .plus l r, .first => some ⟨l, .plusL r :: z.path⟩
      | .plus l r, .second => some ⟨r, .plusR l :: z.path⟩
      | _, _ => none

theorem movement_erasure (h : move d z = some z') : z'.erase = z.erase := by
  rcases z with ⟨e, fs⟩
  cases d with
  | parent => cases fs <;> simp_all [move, ZExpr.erase] <;> cases h <;> rfl
  | child c => cases e <;> cases c <;> simp_all [move, ZExpr.erase, Frame.plug] <;> cases h <;> rfl

inductive TyFrame where
  | left (right : Ty) | right (left : Ty)
  deriving Repr, DecidableEq, BEq

def TyFrame.plug : TyFrame → Ty → Ty
  | .left b, a => .arr a b
  | .right a, b => .arr a b

structure ZTy where
  focus : Ty
  path : List TyFrame := []
  deriving Repr, DecidableEq, BEq

def ZTy.erase (z : ZTy) : Ty := z.path.foldl (fun t f => f.plug t) z.focus

def moveTy (d : Direction) (z : ZTy) : Option ZTy :=
  match d with
  | .parent => match z.path with
      | [] => none
      | f :: fs => some ⟨f.plug z.focus, fs⟩
  | .child c => match z.focus, c with
      | .arr a b, .first => some ⟨a, .left b :: z.path⟩
      | .arr a b, .second => some ⟨b, .right a :: z.path⟩
      | _, _ => none

theorem type_movement_erasure (h : moveTy d z = some z') : z'.erase = z.erase := by
  rcases z with ⟨t, fs⟩
  cases d with
  | parent => cases fs <;> simp_all [moveTy, ZTy.erase] <;> cases h <;> rfl
  | child c => cases t <;> cases c <;> simp_all [moveTy, ZTy.erase, TyFrame.plug] <;> cases h <;> rfl

inductive TyAction where
  | move (direction : Direction) | erase | num | arrow
  deriving Repr, DecidableEq, BEq

def editTy (a : TyAction) (z : ZTy) : Option ZTy :=
  match a with
  | .move d => moveTy d z
  | .erase => some { z with focus := .hole }
  | .num => if z.focus = .hole then some { z with focus := .num } else none
  | .arrow => some ⟨.hole, .right z.focus :: z.path⟩

inductive Mode where
  | syn | ana (expected : Ty)
  deriving Repr, DecidableEq, BEq

def well (Γ : Ctx) (m : Mode) (e : Expr) : Bool :=
  match m with
  | .syn => (synth Γ e).isSome
  | .ana t => check Γ e t

def WellTyped (Γ : Ctx) (m : Mode) (e : Expr) : Prop :=
  match m with
  | .syn => ∃ t, Synth Γ e t
  | .ana t => Check Γ e t

theorem well_sound (h : well Γ m e = true) : WellTyped Γ m e := by
  cases m with
  | ana t => exact check_sound h
  | syn =>
    cases hs : synth Γ e with
    | none => simp [well, hs] at h
    | some t => exact ⟨t, synth_sound hs⟩

/- Recover the focus's inherited mode and scope from the outside inward. -/
def localInfo (Γ : Ctx) (m : Mode) : List Frame → Option (Ctx × Mode)
  | [] => some (Γ, m)
  | f :: fs => do
    let (Δ, n) ← localInfo Γ m fs
    match f with
    | .lam x => match n with
        | .syn => none
        | .ana t => do
          let (a, b) ← matchArrow t
          some ((x, a) :: Δ, .ana b)
    | .appL _ | .nonempty => some (Δ, .syn)
    | .appR fn => do
        let t ← synth Δ fn
        let (a, _) ← matchArrow t
        some (Δ, .ana a)
    | .plusL _ | .plusR _ => some (Δ, .ana .num)
    | .asc t => some (Δ, .ana t)

inductive Action where
  | move (direction : Direction)
  | erase | var (name : String) | lit (value : Nat) | lam (name : String)
  | app | plus | ascribe (type : Ty) | setType (type : Ty) | wrap | finish
  deriving Repr, DecidableEq, BEq

/- Only the variable/literal construction rules insert this mismatch boundary.
The caller has checked the variable is bound. -/
def insertAtom (m : Mode) (t : Ty) (e : Expr) (fs : List Frame) : ZExpr :=
  match m with
  | .syn => ⟨e, fs⟩
  | .ana expected => if consistent t expected then ⟨e, fs⟩ else ⟨e, .nonempty :: fs⟩

def construct (Γ : Ctx) (m : Mode) (a : Action) (z : ZExpr) : Option ZExpr := do
  let (Δ, n) ← localInfo Γ m z.path
  match a with
  | .move d => move d z
  | .erase => some { z with focus := .hole }
  | .var x =>
      if z.focus = .hole then do
        let t ← lookup Δ x
        some (insertAtom n t (.var x) z.path)
      else none
  | .lit k => if z.focus = .hole then
      some (insertAtom n .num (.lit k) z.path) else none
  | .lam x =>
      if z.focus = .hole then
        match n with
        | .ana t => match matchArrow t with
            | some _ => some ⟨.hole, .lam x :: z.path⟩
            | none => some ⟨.hole, .lam x :: .asc (.arr .hole .hole) :: .nonempty :: z.path⟩
        | .syn => some ⟨.hole, .lam x :: .asc (.arr .hole .hole) :: z.path⟩
      else none
  | .app => do
      let t ← synth Δ z.focus
      let fn := if (matchArrow t).isSome then z.focus else .nonempty z.focus
      some ⟨.hole, .appR fn :: z.path⟩
  | .plus => do
      let _ ← synth Δ z.focus
      let left := if check Δ z.focus .num then z.focus else .nonempty z.focus
      some ⟨.hole, .plusR left :: z.path⟩
  | .ascribe t => some ⟨z.focus, .asc t :: z.path⟩
  | .setType t => match z.focus with
      | .asc e _ => some { z with focus := .asc e t }
      | _ => none
  | .wrap => do
      let _ ← synth Δ z.focus
      some ⟨z.focus, .nonempty :: z.path⟩
  | .finish => match z.focus with
      | .nonempty e => some { z with focus := e }
      | _ => none

/- Rechecking the reconstructed term discharges all surrounding zipper premises.
This is an executable partial function, not an action supplied with its proof. -/
def step (Γ : Ctx) (m : Mode) (a : Action) (z : ZExpr) : Option ZExpr := do
  let z' ← construct Γ m a z
  if well Γ m z'.erase then some z' else none

theorem step_checked (h : step Γ m a z = some z') : well Γ m z'.erase = true := by
  unfold step at h
  cases hc : construct Γ m a z <;> simp [hc] at h
  rcases h with ⟨hw, rfl⟩
  exact hw

theorem action_sensibility (h : step Γ m a z = some z') : WellTyped Γ m z'.erase :=
  well_sound (step_checked h)

def react (Γ : Ctx) (m : Mode) (z : ZExpr) (a : Action) : ZExpr :=
  (step Γ m a z).getD z

theorem react_checked (hz : well Γ m z.erase = true) : well Γ m (react Γ m z a).erase = true := by
  unfold react
  cases hs : step Γ m a z with
  | none => exact hz
  | some z' => exact step_checked hs

theorem fold_checked (hz : well Γ m z.erase = true) (actions : List Action) :
    well Γ m (actions.foldl (react Γ m) z).erase = true := by
  induction actions generalizing z with
  | nil => exact hz
  | cons a actions ih => exact ih (react_checked hz)

end Hazelnut
