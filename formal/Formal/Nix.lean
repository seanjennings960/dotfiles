import Std

/-!
A deliberately delimited, call-by-name NixLang fragment. See ../NIX.md for the
boundary with the ICFP 2025 semantics and with the real Nix implementation.
The transition relation is inductive; it is not defined as the graph of `tick`.
-/
namespace Formal.Nix

inductive Kind where
  | abs | withScope
  deriving DecidableEq, Repr, BEq

inductive Mode where
  | shallow | deep
  deriving DecidableEq, Repr, BEq

inductive Expr where
  | num : Nat → Expr
  | bool : Bool → Expr
  | var : String → Option (Kind × Expr) → Expr
  | lam : String → Expr → Expr
  | app : Expr → Expr → Expr
  | attrs : List (String × Expr) → Expr
  | scope : Kind → Expr → Expr → Expr
  | select : Expr → String → Expr
  | cond : Expr → Expr → Expr → Expr
  | seq : Mode → Expr → Expr → Expr
  | equal : Expr → Expr → Expr
  deriving Repr, BEq

abbrev Binding := Kind × Expr
abbrev Subst := String → Option Binding

/-- Only a new `with` meeting an old absolute binding loses. -/
def merge (new old : Option Binding) : Option Binding :=
  match new, old with
  | none, _ => old
  | some (.withScope, _), some (.abs, _) => old
  | some b, _ => some b

/-- Deliberately neither recurse into saved replacements nor remove binders. -/
def subst (σ : Subst) : Expr → Expr
  | .num n => .num n
  | .bool b => .bool b
  | .var x saved => .var x (merge (σ x) saved)
  | .lam x body => .lam x (subst σ body)
  | .app f arg => .app (subst σ f) (subst σ arg)
  | .attrs fields => .attrs (fields.map fun p => (p.1, subst σ p.2))
  | .scope k source body => .scope k (subst σ source) (subst σ body)
  | .select source x => .select (subst σ source) x
  | .cond c yes no => .cond (subst σ c) (subst σ yes) (subst σ no)
  | .seq m first second => .seq m (subst σ first) (subst σ second)
  | .equal a b => .equal (subst σ a) (subst σ b)
termination_by e => sizeOf e
decreasing_by
  all_goals simp_wf
  all_goals try omega
  have hp := List.sizeOf_lt_of_mem ‹p ∈ fields›
  cases p
  simp at hp ⊢
  omega

def singleton (x : String) (b : Binding) : Subst :=
  fun y => if y = x then some b else none

def lookup (x : String) : List (String × Expr) → Option Expr
  | [] => none
  | (y, e) :: rest => if x = y then some e else lookup x rest

def bindings (k : Kind) (fields : List (String × Expr)) : Subst :=
  fun x => (lookup x fields).map (k, ·)

def letOne (x : String) (rhs body : Expr) : Expr :=
  .scope .abs (.attrs [(x, rhs)]) body

theorem with_cannot_override_abs (old new : Expr) :
    merge (some (.withScope, new)) (some (.abs, old)) = some (.abs, old) := rfl

theorem new_abs_overrides (old : Option Binding) (new : Expr) :
    merge (some (.abs, new)) old = some (.abs, new) := by
  cases old <;> rfl

theorem saved_replacement_is_opaque (σ : Subst) (x : String) (b : Binding)
    (h : σ x = none) : subst σ (.var x (some b)) = .var x (some b) := by
  simp [subst, h, merge]

theorem lambda_subst_descends (σ : Subst) (x : String) (e : Expr) :
    subst σ (.lam x e) = .lam x (subst σ e) := by simp [subst]

theorem beta_rebinds_even_saved (x : String) (old : Option Binding) (arg : Expr) :
    subst (singleton x (.abs, arg)) (.var x old) = .var x (some (.abs, arg)) := by
  simp [subst, singleton, new_abs_overrides]

inductive Fault where
  | unbound : String → Fault
  | notFunction | notAttrs | notBool | functionEquality
  | missing : String → Fault
  deriving DecidableEq, Repr, BEq

def isLam : Expr → Bool
  | .lam _ _ => true
  | _ => false

def isAttrs : Expr → Bool
  | .attrs _ => true
  | _ => false

def isBool : Expr → Bool
  | .bool _ => true
  | _ => false

/-- Domain comparison does not inspect any attribute value. -/
def sameDomain (a b : List (String × Expr)) : Bool :=
  a.all (fun p => (lookup p.1 b).isSome) && b.all (fun p => (lookup p.1 a).isSome)

def compareFields (a b : List (String × Expr)) : Expr :=
  a.foldr (fun (x, e) rest =>
    match lookup x b with
    | some e' => .cond (.equal e e') rest (.bool false)
    | none => .bool false) (.bool true)

/-- This operation is called only after shallow evaluation of both operands.
Attribute literals in the source fragment have distinct names; order fixes the
deterministic order of deep traversal. -/
def compareValues (a b : Expr) : Except Fault Expr :=
  match a, b with
  | .num n, .num m => .ok (.bool (n == m))
  | .bool p, .bool q => .ok (.bool (p == q))
  | .lam _ _, .lam _ _ => .error .functionEquality
  | .attrs xs, .attrs ys =>
      .ok (if sameDomain xs ys then compareFields xs ys else .bool false)
  | _, _ => .ok (.bool false)

theorem unequal_domains_skip_values (a b : List (String × Expr))
    (h : sameDomain a b = false) :
    compareValues (.attrs a) (.attrs b) = .ok (.bool false) := by
  simp [compareValues, h]

inductive Frame where
  | apply : Mode → Expr → Frame
  | scope : Mode → Kind → Expr → Frame
  | select : Mode → String → Frame
  | branch : Mode → Expr → Expr → Frame
  | seq : Mode → Expr → Frame
  | eqLeft : Mode → Expr → Frame
  | eqRight : Mode → Expr → Frame
  | field : String → List (String × Expr) → List (String × Expr) → Frame
  deriving Repr, BEq

inductive State where
  | eval : Mode → Expr → List Frame → State
  | ret : Expr → List Frame → State
  | fault : Fault → State
  deriving Repr, BEq

inductive Answer where
  | value : Expr → Answer
  | fault : Fault → Answer
  deriving Repr, BEq

/-- Declarative small-step machine semantics, independent of the interpreter. -/
inductive Step : State → State → Prop where
  | num : Step (.eval m (.num n) k) (.ret (.num n) k)
  | bool : Step (.eval m (.bool b) k) (.ret (.bool b) k)
  | lam : Step (.eval m (.lam x e) k) (.ret (.lam x e) k)
  | unbound : Step (.eval m (.var x none) k) (.fault (.unbound x))
  | deferred : Step (.eval m (.var x (some (kind, e))) k) (.eval m e k)
  | app : Step (.eval m (.app f a) k) (.eval .shallow f (.apply m a :: k))
  | shallowAttrs : Step (.eval .shallow (.attrs fs) k) (.ret (.attrs fs) k)
  | emptyDeepAttrs : Step (.eval .deep (.attrs []) k) (.ret (.attrs []) k)
  | deepAttrs : Step (.eval .deep (.attrs ((x, e) :: fs)) k)
      (.eval .deep e (.field x [] fs :: k))
  | scope : Step (.eval m (.scope kind source body) k)
      (.eval .shallow source (.scope m kind body :: k))
  | select : Step (.eval m (.select source x) k)
      (.eval .shallow source (.select m x :: k))
  | cond : Step (.eval m (.cond c yes no) k)
      (.eval .shallow c (.branch m yes no :: k))
  | seq : Step (.eval m (.seq force first second) k)
      (.eval force first (.seq m second :: k))
  | equal : Step (.eval m (.equal a b) k)
      (.eval .shallow a (.eqLeft m b :: k))
  | beta : Step (.ret (.lam x body) (.apply m arg :: k))
      (.eval m (subst (singleton x (.abs, arg)) body) k)
  | badApply : isLam v = false →
      Step (.ret v (.apply m arg :: k)) (.fault .notFunction)
  | enterScope : Step (.ret (.attrs fs) (.scope m kind body :: k))
      (.eval m (subst (bindings kind fs) body) k)
  | badScope : isAttrs v = false →
      Step (.ret v (.scope m kind body :: k)) (.fault .notAttrs)
  | project : lookup x fs = some e →
      Step (.ret (.attrs fs) (.select m x :: k)) (.eval m e k)
  | missing : lookup x fs = none →
      Step (.ret (.attrs fs) (.select m x :: k)) (.fault (.missing x))
  | badSelect : isAttrs v = false →
      Step (.ret v (.select m x :: k)) (.fault .notAttrs)
  | ifTrue : Step (.ret (.bool true) (.branch m yes no :: k)) (.eval m yes k)
  | ifFalse : Step (.ret (.bool false) (.branch m yes no :: k)) (.eval m no k)
  | badCond : isBool v = false →
      Step (.ret v (.branch m yes no :: k)) (.fault .notBool)
  | nextSeq : Step (.ret v (.seq m second :: k)) (.eval m second k)
  | eqRight : Step (.ret a (.eqLeft m b :: k))
      (.eval .shallow b (.eqRight m a :: k))
  | compared : compareValues a b = .ok e →
      Step (.ret b (.eqRight m a :: k)) (.eval m e k)
  | badCompare : compareValues a b = .error f →
      Step (.ret b (.eqRight m a :: k)) (.fault f)
  | lastField : Step (.ret v (.field x done [] :: k))
      (.ret (.attrs (done ++ [(x, v)])) k)
  | nextField : Step (.ret v (.field x done ((y, e) :: rest) :: k))
      (.eval .deep e (.field y (done ++ [(x, v)]) rest :: k))

inductive Halt : State → Answer → Prop where
  | value : Halt (.ret v []) (.value v)
  | fault : Halt (.fault f) (.fault f)

inductive Tick where
  | more : State → Tick
  | halt : Answer → Tick
  deriving Repr, BEq

/-- One executable machine instruction; no fuel is involved in a single step. -/
def tick : State → Tick
  | .fault f => .halt (.fault f)
  | .eval m e k => match e with
    | .num n => .more (.ret (.num n) k)
    | .bool b => .more (.ret (.bool b) k)
    | .lam x body => .more (.ret (.lam x body) k)
    | .var x none => .more (.fault (.unbound x))
    | .var _ (some (_, body)) => .more (.eval m body k)
    | .app f a => .more (.eval .shallow f (.apply m a :: k))
    | .attrs fs => match m, fs with
      | .shallow, _ => .more (.ret (.attrs fs) k)
      | .deep, [] => .more (.ret (.attrs []) k)
      | .deep, (x, body) :: rest => .more (.eval .deep body (.field x [] rest :: k))
    | .scope kind source body => .more (.eval .shallow source (.scope m kind body :: k))
    | .select source x => .more (.eval .shallow source (.select m x :: k))
    | .cond c yes no => .more (.eval .shallow c (.branch m yes no :: k))
    | .seq force first second => .more (.eval force first (.seq m second :: k))
    | .equal a b => .more (.eval .shallow a (.eqLeft m b :: k))
  | .ret v [] => .halt (.value v)
  | .ret v (frame :: k) => match frame with
    | .apply m arg => match v with
      | .lam x body => .more (.eval m (subst (singleton x (.abs, arg)) body) k)
      | _ => .more (.fault .notFunction)
    | .scope m kind body => match v with
      | .attrs fs => .more (.eval m (subst (bindings kind fs) body) k)
      | _ => .more (.fault .notAttrs)
    | .select m x => match v with
      | .attrs fs => match lookup x fs with
        | some e => .more (.eval m e k)
        | none => .more (.fault (.missing x))
      | _ => .more (.fault .notAttrs)
    | .branch m yes no => match v with
      | .bool true => .more (.eval m yes k)
      | .bool false => .more (.eval m no k)
      | _ => .more (.fault .notBool)
    | .seq m second => .more (.eval m second k)
    | .eqLeft m b => .more (.eval .shallow b (.eqRight m v :: k))
    | .eqRight m a => match compareValues a v with
      | .ok e => .more (.eval m e k)
      | .error f => .more (.fault f)
    | .field x done [] => .more (.ret (.attrs (done ++ [(x, v)])) k)
    | .field x done ((y, e) :: rest) =>
        .more (.eval .deep e (.field y (done ++ [(x, v)]) rest :: k))

theorem step_tick {s t : State} (h : Step s t) : tick s = .more t := by
  cases h <;> simp_all [tick, isLam, isAttrs, isBool]
  all_goals first | rfl | (split <;> simp_all)

theorem tick_spec (s : State) :
    match tick s with
    | .more t => Step s t
    | .halt a => Halt s a := by
  cases s with
  | fault f => exact .fault
  | eval m e k =>
      cases e with
      | num n => exact .num
      | bool b => exact .bool
      | lam x e => exact .lam
      | var x saved =>
          cases saved with
          | none => exact .unbound
          | some pair => cases pair; exact .deferred
      | app f a => exact .app
      | attrs fs =>
          cases m with
          | shallow => exact .shallowAttrs
          | deep => cases fs with
            | nil => exact .emptyDeepAttrs
            | cons pair fs => cases pair; exact .deepAttrs
      | scope kind source body => exact .scope
      | select source x => exact .select
      | cond c yes no => exact .cond
      | seq force first second => exact .seq
      | equal a b => exact .equal
  | ret v k =>
      cases k with
      | nil => exact .value
      | cons frame k =>
          cases frame with
          | apply m arg =>
              cases v <;> first | exact .beta | exact .badApply rfl
          | scope m kind body =>
              cases v <;> first | exact .enterScope | exact .badScope rfl
          | select m x =>
              cases v <;> try exact .badSelect rfl
              rename_i fs
              cases h : lookup x fs with
              | some e => simpa only [tick, h] using (Step.project (m := m) (k := k) h)
              | none => simpa only [tick, h] using (Step.missing (m := m) (k := k) h)
          | branch m yes no =>
              cases v <;> try exact .badCond rfl
              rename_i b
              cases b <;> first | exact .ifTrue | exact .ifFalse
          | seq m second => exact .nextSeq
          | eqLeft m b => exact .eqRight
          | eqRight m a =>
              cases h : compareValues a v with
              | ok e => simpa only [tick, h] using (Step.compared (m := m) (k := k) h)
              | error f => simpa only [tick, h] using (Step.badCompare (m := m) (k := k) h)
          | field x done rest =>
              cases rest with
              | nil => exact .lastField
              | cons pair rest => cases pair; exact .nextField

theorem tick_step_iff {s t : State} : tick s = .more t ↔ Step s t := by
  constructor
  · intro h; have spec := tick_spec s; simpa [h] using spec
  · exact step_tick

theorem halt_tick {s : State} {a : Answer} (h : Halt s a) : tick s = .halt a := by
  cases h <;> rfl

theorem step_deterministic {s t u : State} (h : Step s t) (h' : Step s u) : t = u := by
  have eq := (step_tick h).symm.trans (step_tick h')
  exact Tick.more.inj eq

theorem fault_is_terminal (f : Fault) : ¬ ∃ t, Step (.fault f) t := by
  rintro ⟨t, h⟩; cases h

inductive Steps : Nat → State → State → Prop where
  | refl : Steps 0 s s
  | cons : Step s t → Steps n t u → Steps (n + 1) s u

inductive Result where
  | done : Answer → Result
  | timeout : State → Result
  deriving Repr, BEq

/-- Fuel counts machine instructions, including observation of a terminal state.
Timeout retains the exact resumable state and is never a language fault. -/
def run : Nat → State → Result
  | 0, s => .timeout s
  | fuel + 1, s => match tick s with
    | .halt answer => .done answer
    | .more next => run fuel next

def eval (fuel : Nat) (mode : Mode) (e : Expr) : Result :=
  run fuel (.eval mode e [])

theorem run_sound {fuel : Nat} {s : State} {a : Answer}
    (h : run fuel s = .done a) : ∃ n t, Steps n s t ∧ Halt t a := by
  induction fuel generalizing s with
  | zero => simp [run] at h
  | succ fuel ih =>
      cases ht : tick s with
      | halt answer =>
          simp [run, ht] at h
          subst answer
          exact ⟨0, s, .refl, by simpa [ht] using tick_spec s⟩
      | more next =>
          have hnext : run fuel next = .done a := by simpa [run, ht] using h
          obtain ⟨n, t, steps, terminal⟩ := ih hnext
          exact ⟨n + 1, t, .cons (tick_step_iff.mp ht) steps, terminal⟩

theorem run_complete {n : Nat} {s t : State} {a : Answer}
    (steps : Steps n s t) (terminal : Halt t a) : run (n + 1) s = .done a := by
  induction steps with
  | refl => simp [run, halt_tick terminal]
  | cons step rest ih => simpa [run, step_tick step] using ih terminal

/-- Full finite-termination correspondence, for both values and genuine faults. -/
theorem interpreter_correspondence (s : State) (a : Answer) :
    (∃ fuel, run fuel s = .done a) ↔ (∃ n t, Steps n s t ∧ Halt t a) := by
  constructor
  · rintro ⟨fuel, h⟩; exact run_sound h
  · rintro ⟨n, t, steps, terminal⟩; exact ⟨n + 1, run_complete steps terminal⟩

theorem more_fuel_same_answer {fuel : Nat} {s : State} {a : Answer}
    (h : run fuel s = .done a) (extra : Nat) : run (fuel + extra) s = .done a := by
  induction fuel generalizing s with
  | zero => simp [run] at h
  | succ fuel ih =>
      cases ht : tick s with
      | halt answer => simpa [run, ht, Nat.succ_add] using h
      | more next =>
          simp only [run, ht] at h
          simpa [run, ht, Nat.succ_add] using ih h

/-- A timeout represents a real finite prefix, not a fabricated error. -/
theorem timeout_prefix {fuel : Nat} {s t : State} (h : run fuel s = .timeout t) :
    Steps fuel s t := by
  induction fuel generalizing s with
  | zero => simp [run] at h; subst t; exact .refl
  | succ fuel ih =>
      cases ht : tick s with
      | halt answer => simp [run, ht] at h
      | more next =>
          exact .cons (tick_step_iff.mp ht) (ih (by simpa [run, ht] using h))

/-- Every finitely reachable state can take another semantic instruction. -/
def Diverges (s : State) : Prop := ∀ n t, Steps n s t → ∃ u, Step t u

/-- All fuel bounds timing out characterizes divergence; one timeout does not. -/
theorem divergence_correspondence (s : State) :
    (∀ fuel, ∃ t, run fuel s = .timeout t) ↔ Diverges s := by
  constructor
  · intro allTimeout n t reachable
    cases ht : tick t with
    | more u => exact ⟨u, tick_step_iff.mp ht⟩
    | halt a =>
        have terminal : Halt t a := by simpa [ht] using tick_spec t
        have completed := run_complete reachable terminal
        obtain ⟨u, timedOut⟩ := allTimeout (n + 1)
        rw [completed] at timedOut
        contradiction
  · intro infinite fuel
    induction fuel generalizing s with
    | zero => exact ⟨s, rfl⟩
    | succ fuel ih =>
        obtain ⟨next, step⟩ := infinite 0 s .refl
        have nextInfinite : Diverges next := fun n t path =>
          infinite (n + 1) t (.cons step path)
        obtain ⟨last, timedOut⟩ := ih next nextInfinite
        exact ⟨last, by simpa [run, step_tick step] using timedOut⟩

namespace Examples

def x : Expr := .var "x" none
def y : Expr := .var "y" none
def delta : Expr := .lam "x" (.app x x)
def omega : Expr := .app delta delta

def lexicalPriority : Expr :=
  letOne "x" (.num 7) (.scope .withScope (.attrs [("x", .num 99)]) x)

def innerLambdaWins : Expr :=
  letOne "x" (.num 7) (.app (.lam "x" x) (.num 42))

/-- If substitution traversed saved replacements, this would incorrectly be 99. -/
def savedClosure : Expr :=
  letOne "x" (.num 7) (letOne "y" x (letOne "x" (.num 99) y))

def shallowLazy : Expr := .seq .shallow (.attrs [("bad", omega)]) (.bool true)
def deepForces : Expr := .seq .deep (.attrs [("bad", .var "missing" none)]) (.bool true)
def domainsFirst : Expr := .equal (.attrs [("a", omega)]) (.attrs [("b", omega)])
def sameSizeDomainsFirst : Expr :=
  .equal (.attrs [("a", omega), ("b", .num 1)])
    (.attrs [("a", omega), ("c", .num 2)])
def nestedDeep : Expr := .attrs [("outer", .attrs [("answer", .app (.lam "x" x) (.num 42))])]
def functionComparison : Expr := .equal (.lam "x" x) (.lam "x" x)

example : eval 40 .shallow lexicalPriority = .done (.value (.num 7)) := by
  simp [eval, run, tick, lexicalPriority, letOne, x, subst, bindings, lookup, merge]
example : eval 40 .shallow innerLambdaWins = .done (.value (.num 42)) := by
  simp [eval, run, tick, innerLambdaWins, letOne, x, subst, bindings, lookup, merge, singleton]
example : eval 60 .shallow savedClosure = .done (.value (.num 7)) := by
  simp [eval, run, tick, savedClosure, letOne, x, y, subst, bindings, lookup, merge]
example : eval 20 .shallow (.app (.lam "unused" (.num 42)) omega) =
    .done (.value (.num 42)) := by simp [eval, run, tick, subst]
example : eval 20 .shallow shallowLazy = .done (.value (.bool true)) := rfl
example : eval 20 .shallow deepForces = .done (.fault (.unbound "missing")) := rfl
example : eval 20 .shallow domainsFirst = .done (.value (.bool false)) := rfl
example : eval 20 .shallow sameSizeDomainsFirst = .done (.value (.bool false)) := rfl
-- Like the paper's artifact, this model faults; native Nix returns false.
example : eval 20 .shallow functionComparison = .done (.fault .functionEquality) := rfl
example : eval 40 .deep nestedDeep =
    .done (.value (.attrs [("outer", .attrs [("answer", .num 42)])])) := by
  simp [eval, run, tick, nestedDeep, x, subst, singleton, merge]
example : eval 20 .shallow (.app (.num 1) omega) =
    .done (.fault .notFunction) := rfl
example : (match eval 100 .shallow omega with | .timeout _ => true | _ => false) = true := by
  decide +kernel
/-- Paper semantics eagerly examines the source even if the body ignores it. -/
example : (match eval 100 .shallow (.scope .withScope omega (.bool true)) with
    | .timeout _ => true | _ => false) = true := by decide +kernel

def report : List (String × Result) :=
  [("lexical-over-with", eval 80 .shallow lexicalPriority),
   ("inner-absolute-rebinding", eval 80 .shallow innerLambdaWins),
   ("opaque-saved-closure", eval 80 .shallow savedClosure),
   ("shallow-does-not-force-fields", eval 80 .shallow shallowLazy),
   ("deep-fault", eval 80 .shallow deepForces),
   ("domain-before-values", eval 80 .shallow domainsFirst),
   ("function-equality-fault", eval 80 .shallow functionComparison),
   ("nested-deep", eval 80 .deep nestedDeep)]

end Examples
end Formal.Nix
