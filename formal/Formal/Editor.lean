import Formal.Hazelnut

/-! A single-document, UTF-16 projection, lexical definition service, and
asynchronous reactive editor. No caller supplies a certified definition target. -/
namespace Editor
open Hazelnut

structure Position where
  line : Nat
  character : Nat
  deriving Repr, DecidableEq, BEq

def Position.BeforeEq (a b : Position) : Prop :=
  a.line < b.line ∨ (a.line = b.line ∧ a.character ≤ b.character)

instance (a b : Position) : Decidable (a.BeforeEq b) := inferInstanceAs
  (Decidable (a.line < b.line ∨ (a.line = b.line ∧ a.character ≤ b.character)))

structure Range where
  start : Position
  «end» : Position
  deriving Repr, DecidableEq, BEq

def Range.Valid (r : Range) : Prop := r.start.BeforeEq r.end
def Range.Contains (outer inner : Range) : Prop :=
  outer.start.BeforeEq inner.start ∧ inner.end.BeforeEq outer.end

/- The projection is a single line. Positions on another line or at a token's
exclusive end do not hit that token. Columns count UTF-16 code units. -/
structure Span where
  start : Nat
  width : Nat
  deriving Repr, DecidableEq, BEq

def Span.range (s : Span) : Range := ⟨⟨0, s.start⟩, ⟨0, s.start + s.width⟩⟩
def Span.hit (s : Span) (p : Position) : Bool :=
  p.line == 0 && decide (s.start ≤ p.character ∧ p.character < s.start + s.width)

theorem span_valid (s : Span) : s.range.Valid := by
  simp [Range.Valid, Span.range, Position.BeforeEq]

def utf16Units (c : Char) : Nat := if c.toNat ≤ 0xFFFF then 1 else 2

/- Lean 4.29's String.toList depends on Classical.choice internally. Counting
valid UTF-8 leading bytes avoids that dependency: continuation bytes contribute
zero, four-byte leaders two UTF-16 units, other leaders one. -/
def utf16ByteWeight (b : UInt8) : Nat :=
  if b.toNat < 128 then 1 else if b.toNat < 192 then 0 else
  if b.toNat < 240 then 1 else 2

def utf16Length (s : String) : Nat :=
  (s.toByteArray.data.toList.map utf16ByteWeight).sum

theorem utf16Length_append (a b : String) :
    utf16Length (a ++ b) = utf16Length a + utf16Length b := by
  simp [utf16Length, String.toByteArray_append, ByteArray.data_append,
    Array.toList_append, List.map_append, List.sum_append]

/- Explicit structural UTF-8 decoding for escaping identifiers, without the
choice-dependent String iterators. Inputs here come from valid Lean Strings. -/
def utf8Chars : List UInt8 → List Char
  | [] => []
  | b :: bs =>
    if b.toNat < 128 then Char.ofNat b.toNat :: utf8Chars bs
    else if b.toNat < 224 then match bs with
      | c :: cs => Char.ofNat ((b.toNat % 32) * 64 + c.toNat % 64) :: utf8Chars cs
      | [] => []
    else if b.toNat < 240 then match bs with
      | c :: d :: ds => Char.ofNat ((b.toNat % 16) * 4096 +
          (c.toNat % 64) * 64 + d.toNat % 64) :: utf8Chars ds
      | _ => []
    else match bs with
      | c :: d :: e :: es => Char.ofNat ((b.toNat % 8) * 262144 +
          (c.toNat % 64) * 4096 + (d.toNat % 64) * 64 + e.toNat % 64) :: utf8Chars es
      | _ => []

/- Quoting also makes empty names and names with punctuation unambiguous.
Escaping LF/CR ensures a single-line projection even for arbitrary String names. -/
def escapeChar (c : Char) : String :=
  if c = '\n' then "\\n" else if c = '\r' then "\\r" else
  if c = '"' then "\\\"" else if c = '\\' then "\\\\" else String.singleton c

def nameText (x : String) : String :=
  "\"" ++ String.join ((utf8Chars x.toByteArray.data.toList).map escapeChar) ++ "\""

def renderTy : Ty → String
  | .hole => "?"
  | .num => "num"
  | .arr a b => "(" ++ renderTy a ++ " -> " ++ renderTy b ++ ")"

def render : Expr → String
  | .hole => "□"
  | .nonempty e => "⦇" ++ render e ++ "⦈"
  | .var x => nameText x
  | .lit n => toString n
  | .lam x e => "(λ" ++ nameText x ++ ". " ++ render e ++ ")"
  | .app f a => "(" ++ render f ++ " " ++ render a ++ ")"
  | .plus l r => "(" ++ render l ++ " + " ++ render r ++ ")"
  | .asc e t => "(" ++ render e ++ " : " ++ renderTy t ++ ")"

theorem width_nonempty : utf16Length (render (.nonempty e)) = 1 + utf16Length (render e) + 1 := by
  simp only [render, utf16Length_append]; rfl
theorem width_lam : utf16Length (render (.lam x e)) =
    2 + utf16Length (nameText x) + 2 + utf16Length (render e) + 1 := by
  simp only [render, utf16Length_append]; rfl
theorem width_app : utf16Length (render (.app f a)) =
    1 + utf16Length (render f) + 1 + utf16Length (render a) + 1 := by
  simp only [render, utf16Length_append]; rfl
theorem width_plus : utf16Length (render (.plus l r)) =
    1 + utf16Length (render l) + 3 + utf16Length (render r) + 1 := by
  simp only [render, utf16Length_append]; rfl
theorem width_asc : utf16Length (render (.asc e t)) =
    1 + utf16Length (render e) + 3 + utf16Length (renderTy t) + 1 := by
  simp only [render, utf16Length_append]; rfl

/- A binding is made from the encountered lambda, not from an arbitrary range. -/
structure Binding where
  name : String
  body : Expr
  start : Nat
  deriving Repr, DecidableEq, BEq

def Binding.whole (b : Binding) : Range :=
  (Span.mk b.start (utf16Length (render (.lam b.name b.body)))).range

def Binding.selection (b : Binding) : Range :=
  (Span.mk (b.start + 2) (utf16Length (nameText b.name))).range

theorem binding_contains_selection (b : Binding) : b.whole.Contains b.selection := by
  simp [Binding.whole, Binding.selection, Range.Contains, Span.range,
    Position.BeforeEq, width_lam]
  omega

structure Reference where
  name : String
  span : Span
  scope : List Binding
  deriving Repr, DecidableEq, BEq

/- Nearest binder first; entering a nonempty hole keeps the lexical scope. -/
def references : Expr → Nat → List Binding → List Reference
  | .hole, _, _ | .lit _, _, _ => []
  | .var x, start, scope => [⟨x, ⟨start, utf16Length (nameText x)⟩, scope⟩]
  | .nonempty e, start, scope => references e (start + 1) scope
  | .lam x e, start, scope =>
      references e (start + 2 + utf16Length (nameText x) + 2) (⟨x, e, start⟩ :: scope)
  | .app f a, start, scope => references f (start + 1) scope ++
      references a (start + 1 + utf16Length (render f) + 1) scope
  | .plus l r, start, scope => references l (start + 1) scope ++
      references r (start + 1 + utf16Length (render l) + 3) scope
  | .asc e _, start, scope => references e (start + 1) scope

def bindings : Expr → Nat → List Binding
  | .hole, _ | .var _, _ | .lit _, _ => []
  | .nonempty e, start => bindings e (start + 1)
  | .lam x e, start => ⟨x, e, start⟩ ::
      bindings e (start + 2 + utf16Length (nameText x) + 2)
  | .app f a, start => bindings f (start + 1) ++
      bindings a (start + 1 + utf16Length (render f) + 1)
  | .plus l r, start => bindings l (start + 1) ++
      bindings r (start + 1 + utf16Length (render l) + 3)
  | .asc e _, start => bindings e (start + 1)

theorem reference_bounds (h : r ∈ references e start scope) :
    start ≤ r.span.start ∧ r.span.start + r.span.width ≤ start + utf16Length (render e) := by
  induction e generalizing start scope with
  | hole => simp [references] at h
  | lit _ => simp [references] at h
  | var x => simp only [references, List.mem_singleton] at h; subst r; simp [render]
  | nonempty e ih => have := ih h; rw [width_nonempty]; constructor <;> omega
  | lam x e ih => have := ih h; rw [width_lam]; constructor <;> omega
  | asc e t ih => have := ih h; rw [width_asc]; constructor <;> omega
  | app f a iff ia =>
    rw [width_app]
    simp only [references, List.mem_append] at h
    rcases h with h | h
    · have := iff h; constructor <;> omega
    · have := ia h; constructor <;> omega
  | plus l r il ir =>
    rw [width_plus]
    simp only [references, List.mem_append] at h
    rcases h with h | h
    · have := il h; constructor <;> omega
    · have := ir h; constructor <;> omega

theorem binding_bounds (h : b ∈ bindings e start) :
    start ≤ b.start ∧ b.start + utf16Length (render (.lam b.name b.body)) ≤
      start + utf16Length (render e) := by
  induction e generalizing start with
  | hole => simp [bindings] at h
  | lit _ => simp [bindings] at h
  | var _ => simp [bindings] at h
  | nonempty e ih => have := ih h; rw [width_nonempty]; constructor <;> omega
  | asc e t ih => have := ih h; rw [width_asc]; constructor <;> omega
  | lam x e ih =>
    simp only [bindings, List.mem_cons] at h
    rcases h with rfl | h
    · simp
    · have := ih h; simp only [width_lam] at *; constructor <;> omega
  | app f a iff ia =>
    rw [width_app]
    simp only [bindings, List.mem_append] at h
    rcases h with h | h
    · have := iff h; constructor <;> omega
    · have := ia h; constructor <;> omega
  | plus l r il ir =>
    rw [width_plus]
    simp only [bindings, List.mem_append] at h
    rcases h with h | h
    · have := il h; constructor <;> omega
    · have := ir h; constructor <;> omega

theorem scope_sources (hr : r ∈ references e start scope) (hb : b ∈ r.scope) :
    b ∈ scope ∨ b ∈ bindings e start := by
  induction e generalizing start scope with
  | hole => simp [references] at hr
  | lit _ => simp [references] at hr
  | var x =>
    simp only [references, List.mem_singleton] at hr
    subst r; exact Or.inl hb
  | nonempty e ih => exact ih hr
  | asc e t ih => exact ih hr
  | lam x e ih =>
    obtain h | h := ih hr
    · simp only [List.mem_cons] at h
      rcases h with h | h
      · exact Or.inr (List.mem_cons.mpr (Or.inl h))
      · exact Or.inl h
    · exact Or.inr (List.mem_cons_of_mem _ h)
  | app f a iff ia =>
    simp only [references, List.mem_append] at hr
    rcases hr with hr | hr
    · rcases iff hr with h | h
      · exact Or.inl h
      · exact Or.inr (List.mem_append.mpr (Or.inl h))
    · rcases ia hr with h | h
      · exact Or.inl h
      · exact Or.inr (List.mem_append.mpr (Or.inr h))
  | plus l r il ir =>
    simp only [references, List.mem_append] at hr
    rcases hr with hr | hr
    · rcases il hr with h | h
      · exact Or.inl h
      · exact Or.inr (List.mem_append.mpr (Or.inl h))
    · rcases ir hr with h | h
      · exact Or.inl h
      · exact Or.inr (List.mem_append.mpr (Or.inr h))

def lookupBinding (x : String) : List Binding → Option Binding
  | [] => none
  | b :: bs => if x = b.name then some b else lookupBinding x bs

/- This relation disallows skipping a matching, shadowing binder. -/
inductive Lexical (x : String) : List Binding → Binding → Prop where
  | here : x = b.name → Lexical x (b :: bs) b
  | there : x ≠ b.name → Lexical x bs target → Lexical x (b :: bs) target

theorem lookupBinding_sound (h : lookupBinding x bs = some b) : Lexical x bs b := by
  induction bs with
  | nil => simp [lookupBinding] at h
  | cons a bs ih =>
    simp only [lookupBinding] at h
    split at h
    next he => cases h; exact .here he
    next hn => exact .there hn (ih h)

theorem lookupBinding_complete (h : Lexical x bs b) : lookupBinding x bs = some b := by
  induction h with
  | here he => simp [lookupBinding, he]
  | there hn _ ih => simp [lookupBinding, hn, ih]

theorem lexical_unique (h : Lexical x bs a) (h' : Lexical x bs b) : a = b := by
  have := (lookupBinding_complete h).symm.trans (lookupBinding_complete h')
  exact Option.some.inj this

theorem lexical_member (h : Lexical x bs b) : b ∈ bs ∧ x = b.name := by
  induction h with
  | here he => exact ⟨List.mem_cons_self, he⟩
  | there _ _ ih => exact ⟨List.mem_cons_of_mem _ ih.1, ih.2⟩

theorem shadowing (b : Binding) (bs : List Binding) :
    lookupBinding b.name (b :: bs) = some b := by simp [lookupBinding]

theorem nonempty_preserves_scope :
    references (.nonempty e) start scope = references e (start + 1) scope := rfl

def resolveRefs (rs : List Reference) (p : Position) : Option (Reference × Binding) :=
  match rs with
  | [] => none
  | r :: rs => if r.span.hit p then (lookupBinding r.name r.scope).map (r, ·)
      else resolveRefs rs p

theorem resolveRefs_sound (h : resolveRefs rs p = some (r, b)) :
    r ∈ rs ∧ r.span.hit p = true ∧ Lexical r.name r.scope b := by
  induction rs with
  | nil => simp [resolveRefs] at h
  | cons a rs ih =>
    simp only [resolveRefs] at h
    split at h
    next hh =>
      cases hl : lookupBinding a.name a.scope with
      | none => simp [hl] at h
      | some target =>
        simp only [hl, Option.map_some, Option.some.injEq, Prod.mk.injEq] at h
        rcases h with ⟨rfl, rfl⟩
        exact ⟨List.mem_cons_self, hh, lookupBinding_sound hl⟩
    next =>
      obtain ⟨hm, hh, hl⟩ := ih h
      exact ⟨List.mem_cons_of_mem _ hm, hh, hl⟩

def resolve (e : Expr) (p : Position) : Option (Reference × Binding) :=
  resolveRefs (references e 0 []) p

structure Location where
  uri : String
  range : Range
  deriving Repr, DecidableEq, BEq

structure LocationLink where
  originSelectionRange : Range
  targetUri : String
  targetRange : Range
  targetSelectionRange : Range
  deriving Repr, DecidableEq, BEq

def LocationLink.Valid (l : LocationLink) : Prop :=
  l.originSelectionRange.Valid ∧ l.targetRange.Valid ∧ l.targetSelectionRange.Valid ∧
  l.targetRange.Contains l.targetSelectionRange

def link (uri : String) (r : Reference) (b : Binding) : LocationLink :=
  ⟨r.span.range, uri, b.whole, b.selection⟩

theorem link_valid : (link uri r b).Valid :=
  ⟨span_valid _, span_valid _, span_valid _, binding_contains_selection _⟩

def definition (uri : String) (e : Expr) (p : Position) : Option LocationLink :=
  (resolve e p).map (fun (r, b) => link uri r b)

/- Successful navigation witnesses an actual variable occurrence in the syntax
index and a nearest lexical binder in the scope built by that traversal. -/
theorem definition_sound (h : definition uri e p = some l) :
    ∃ r b, r ∈ references e 0 [] ∧ r.span.hit p = true ∧
      Lexical r.name r.scope b ∧ l = link uri r b := by
  unfold definition at h
  cases hr : resolve e p with
  | none => simp [hr] at h
  | some rb =>
    rcases rb with ⟨r, b⟩
    simp [hr] at h
    obtain ⟨hm, hh, hl⟩ := resolveRefs_sound hr
    exact ⟨r, b, hm, hh, hl, h.symm⟩

theorem definition_valid (h : definition uri e p = some l) : l.Valid := by
  obtain ⟨_, _, _, _, _, rfl⟩ := definition_sound h
  exact link_valid

theorem definition_target_in_syntax (h : definition uri e p = some l) :
    ∃ b, b ∈ bindings e 0 ∧ l.targetUri = uri ∧
      l.targetRange = b.whole ∧ l.targetSelectionRange = b.selection := by
  obtain ⟨r, b, hr, _, hl, rfl⟩ := definition_sound h
  have hm := scope_sources hr (lexical_member hl).1
  simp only [List.not_mem_nil, false_or] at hm
  exact ⟨b, hm, rfl, rfl, rfl⟩

def Range.InProjection (r : Range) (e : Expr) : Prop :=
  r.start.line = 0 ∧ r.end.line = 0 ∧ r.end.character ≤ utf16Length (render e)

theorem definition_spans (h : definition uri e p = some l) :
    l.originSelectionRange.InProjection e ∧ l.targetRange.InProjection e ∧
      l.targetSelectionRange.InProjection e := by
  obtain ⟨r, b, hr, _, hl, rfl⟩ := definition_sound h
  have hb := scope_sources hr (lexical_member hl).1
  simp only [List.not_mem_nil, false_or] at hb
  have hbr := (binding_bounds hb).2
  have hrr := (reference_bounds hr).2
  have hc := (binding_contains_selection b).2
  simp only [Binding.whole, Binding.selection, Span.range, Position.BeforeEq] at hc
  simp only [Range.InProjection, link, Binding.whole, Binding.selection, Span.range]
  simp only [Nat.zero_add] at hbr hrr
  exact ⟨⟨trivial, trivial, hrr⟩, ⟨trivial, trivial, hbr⟩, ⟨trivial, trivial, by omega⟩⟩

theorem hole_has_no_definition : definition uri .hole p = none := rfl

def maxUInt : Nat := 2147483647

def Range.WireValid (r : Range) : Prop :=
  r.Valid ∧ r.start.line ≤ maxUInt ∧ r.end.line ≤ maxUInt ∧
    r.start.character ≤ maxUInt ∧ r.end.character ≤ maxUInt

theorem range_wire_valid {r : Range} {e : Expr} (hv : r.Valid) (hp : r.InProjection e)
    (hs : utf16Length (render e) ≤ maxUInt) : r.WireValid := by
  refine ⟨hv, ?_⟩
  rcases hp with ⟨hl, hl', he⟩
  simp only [Range.Valid, Position.BeforeEq, hl, hl'] at hv
  dsimp [maxUInt] at *
  refine ⟨?_, ?_, ?_, ?_⟩ <;> omega

inductive PositionEncoding where
  | utf16
  deriving Repr, DecidableEq, BEq

structure ServerCapabilities where
  definitionProvider : Bool := true
  positionEncoding : PositionEncoding := .utf16
  deriving Repr, DecidableEq, BEq

structure ClientCapabilities where
  linkSupport : Bool := false
  deriving Repr, DecidableEq, BEq

/- LSP permits Location | Location[] | LocationLink[] | null. This service emits
null or a singleton array; links require the client's linkSupport capability. -/
inductive DefinitionResult where
  | null
  | locations (items : List Location)
  | links (items : List LocationLink)
  deriving Repr, DecidableEq, BEq

def answer (client : ClientCapabilities) (uri : String) (e : Expr) (p : Position) : DefinitionResult :=
  if utf16Length (render e) ≤ maxUInt then
    match definition uri e p with
    | none => .null
    | some l => if client.linkSupport then .links [l]
        else .locations [⟨l.targetUri, l.targetSelectionRange⟩]
  else .null

def DefinitionResult.Valid : DefinitionResult → Prop
  | .null => True
  | .locations xs => ∀ x ∈ xs, x.range.Valid
  | .links xs => ∀ x ∈ xs, x.Valid

theorem answer_valid : (answer client uri e p).Valid := by
  by_cases hs : utf16Length (render e) ≤ maxUInt
  · cases h : definition uri e p with
    | none => simp [answer, hs, h, DefinitionResult.Valid]
    | some l =>
      have hv := definition_valid h
      cases hc : client.linkSupport <;>
        simp_all [answer, DefinitionResult.Valid, LocationLink.Valid]
  · simp [answer, hs, DefinitionResult.Valid]

def DefinitionResult.WireValid : DefinitionResult → Prop
  | .null => True
  | .locations xs => ∀ x ∈ xs, x.range.WireValid
  | .links xs => ∀ x ∈ xs, x.Valid ∧ x.originSelectionRange.WireValid ∧
      x.targetRange.WireValid ∧ x.targetSelectionRange.WireValid

theorem answer_wire_valid : (answer client uri e p).WireValid := by
  by_cases hs : utf16Length (render e) ≤ maxUInt
  · cases h : definition uri e p with
    | none => simp [answer, hs, h, DefinitionResult.WireValid]
    | some l =>
      have hv := definition_valid h
      have hp := definition_spans h
      have ho := range_wire_valid hv.1 hp.1 hs
      have ht := range_wire_valid hv.2.1 hp.2.1 hs
      have hn := range_wire_valid hv.2.2.1 hp.2.2 hs
      cases hc : client.linkSupport <;>
        simp_all [answer, DefinitionResult.WireValid]
  · simp [answer, hs, DefinitionResult.WireValid]

structure TextDocumentIdentifier where
  uri : String
  deriving Repr, DecidableEq, BEq

structure DefinitionParams where
  textDocument : TextDocumentIdentifier
  position : Position
  deriving Repr, DecidableEq, BEq

/- Version and snapshot are local request bookkeeping, not fields added to LSP's
DefinitionParams or its response. Replies correlate through JSON-RPC's id. -/
structure Pending where
  id : Nat
  params : DefinitionParams
  version : Nat
  snapshot : Expr
  client : ClientCapabilities
  deriving Repr, DecidableEq, BEq

structure Reply where
  id : Nat
  result : DefinitionResult
  deriving Repr, DecidableEq, BEq

def serve (p : Pending) : Reply :=
  ⟨p.id, answer p.client p.params.textDocument.uri p.snapshot p.params.position⟩

structure Navigation where
  position : Position
  version : Nat
  result : DefinitionResult
  deriving Repr, DecidableEq, BEq

inductive Status where
  | ready | edited | moved | editRejected | requested | unsupported
  | accepted | stale | unexpected | invalidResponse
  deriving Repr, DecidableEq, BEq

structure State where
  zipper : ZExpr := ⟨.hole, []⟩
  version : Nat := 0
  uri : String := "file:///example.hz"
  server : ServerCapabilities := {}
  client : ClientCapabilities := {}
  nextRequestId : Nat := 0
  pending : Option Pending := none
  navigation : Option Navigation := none
  status : Status := .ready
  deriving Repr, DecidableEq, BEq

inductive Event where
  | edit (action : Action)
  | definition (position : Position)
  | response (reply : Reply)
  deriving Repr, DecidableEq, BEq

def update (Γ : Ctx) (m : Mode) (s : State) (event : Event) : State :=
  match event with
  | .edit a => match step Γ m a s.zipper with
      | none => { s with status := .editRejected }
      | some z =>
          if z.erase = s.zipper.erase then { s with zipper := z, status := .moved }
          else { s with zipper := z, version := s.version + 1, navigation := none, status := .edited }
  | .definition pos =>
      if s.server.definitionProvider then
        { s with
          pending := some ⟨s.nextRequestId, ⟨⟨s.uri⟩, pos⟩, s.version, s.zipper.erase, s.client⟩
          nextRequestId := s.nextRequestId + 1
          status := .requested }
      else { s with status := .unsupported }
  | .response r => match s.pending with
      | none => { s with status := .unexpected }
      | some p =>
          if r.id ≠ p.id then { s with status := .unexpected }
          else if p.version ≠ s.version ∨ p.params.textDocument.uri ≠ s.uri ∨
              p.snapshot ≠ s.zipper.erase then
            { s with pending := none, navigation := none, status := .stale }
          else if r.result = answer s.client s.uri s.zipper.erase p.params.position then
            { s with
              pending := none
              navigation := some ⟨p.params.position, s.version, r.result⟩
              status := .accepted }
          else { s with pending := none, navigation := none, status := .invalidResponse }

def Invariant (Γ : Ctx) (m : Mode) (s : State) : Prop :=
  well Γ m s.zipper.erase = true ∧
  match s.navigation with
  | none => True
  | some n => n.version = s.version ∧
      n.result = answer s.client s.uri s.zipper.erase n.position

theorem update_invariant (h : Invariant Γ m s) : Invariant Γ m (update Γ m s event) := by
  rcases h with ⟨ht, hn⟩
  cases event with
  | edit a =>
    cases hs : step Γ m a s.zipper with
    | none => simpa only [update, hs] using (show Invariant Γ m s from ⟨ht, hn⟩)
    | some z =>
      have hz := step_checked hs
      simp only [update, hs]
      split
      next he => simpa [Invariant, he] using (show Invariant Γ m s from ⟨ht, hn⟩)
      next => exact ⟨hz, trivial⟩
  | definition pos => simp only [update]; split <;> exact ⟨ht, hn⟩
  | response r =>
    cases hp : s.pending with
    | none => simpa only [update, hp] using (show Invariant Γ m s from ⟨ht, hn⟩)
    | some p =>
      simp only [update, hp]
      split
      next => exact ⟨ht, hn⟩
      next =>
        split
        next => exact ⟨ht, trivial⟩
        next =>
          split
          next he => exact ⟨ht, rfl, he⟩
          next => exact ⟨ht, trivial⟩

def run (Γ : Ctx) (m : Mode) (s : State) (events : List Event) : State :=
  events.foldl (update Γ m) s

theorem reactive_invariant (h : Invariant Γ m s) (events : List Event) :
    Invariant Γ m (run Γ m s events) := by
  induction events generalizing s with
  | nil => exact h
  | cons e events ih => exact ih (update_invariant h)

theorem navigation_sound (h : Invariant Γ m s) (hn : s.navigation = some n) :
    n.version = s.version ∧ n.result = answer s.client s.uri s.zipper.erase n.position ∧
    n.result.Valid := by
  have hi := h.2
  rw [hn] at hi
  exact ⟨hi.1, hi.2, hi.2 ▸ answer_valid⟩

theorem navigation_wire_valid (h : Invariant Γ m s) (hn : s.navigation = some n) :
    n.result.WireValid := by
  rw [(navigation_sound h hn).2.1]
  exact answer_wire_valid

def DefinitionResult.selection : DefinitionResult → Option Range
  | .locations (l :: _) => some l.range
  | .links (l :: _) => some l.targetSelectionRange
  | _ => none

structure View where
  text : String
  version : Nat
  selection : Option Range
  status : Status
  deriving Repr, DecidableEq, BEq

/- A successful go-to-definition changes the source selection exposed to a UI.
Binder names are tokens, rather than expression-cursor positions. -/
def view (s : State) : View :=
  ⟨render s.zipper.erase, s.version, s.navigation.bind (fun n => n.result.selection), s.status⟩

theorem selection_valid {result : DefinitionResult} {r : Range}
    (hv : result.Valid) (hs : result.selection = some r) : r.Valid := by
  cases result with
  | null => simp [DefinitionResult.selection] at hs
  | locations xs =>
    cases xs with
    | nil => simp [DefinitionResult.selection] at hs
    | cons l xs =>
      simp only [DefinitionResult.selection, Option.some.injEq] at hs
      subst r; exact hv l List.mem_cons_self
  | links xs =>
    cases xs with
    | nil => simp [DefinitionResult.selection] at hs
    | cons l xs =>
      simp only [DefinitionResult.selection, Option.some.injEq] at hs
      subst r; exact (hv l List.mem_cons_self).2.2.1

theorem view_selection_valid (h : Invariant Γ m s) (hs : (view s).selection = some r) : r.Valid := by
  cases hn : s.navigation with
  | none => simp [view, hn] at hs
  | some n =>
    exact selection_valid (navigation_sound h hn).2.2 (by simpa [view, hn] using hs)

theorem stale_response_rejected (hp : s.pending = some p) (hid : r.id = p.id)
    (hv : p.version ≠ s.version) :
    (update Γ m s (.response r)).status = .stale ∧
    (update Γ m s (.response r)).navigation = none := by
  simp [update, hp, hid, hv]

theorem initial_invariant : Invariant Γ .syn ({} : State) := by
  exact ⟨rfl, trivial⟩

end Editor
