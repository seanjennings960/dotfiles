import Formal.Editor

open Hazelnut Editor

namespace EditorExamples

def incrCtx : Ctx := [("incr", .arr .num .num)]

def incrActions : List Action :=
  [.var "incr", .app, .var "incr", .app, .lit 3,
   .move .parent, .move .parent, .finish]

def nestedIncrement : Expr := .app (.var "incr") (.app (.var "incr") (.lit 3))

def edited : State := run incrCtx .syn {} (incrActions.map Event.edit)

example : edited.zipper.erase = nestedIncrement := by decide
example : edited.version = 6 := by decide
example : synth incrCtx edited.zipper.erase = some .num := by decide

def mismatch : State := run incrCtx .syn {} ([.var "incr", .app, .var "incr"].map Event.edit)

example : mismatch.zipper.erase = .app (.var "incr") (.nonempty (.var "incr")) := by decide
example : (run incrCtx .syn mismatch [.edit (.move .parent), .edit .finish]).status =
    .editRejected := by decide

def shadow : Expr :=
  .asc (.lam "x" (.plus (.var "x")
    (.app (.asc (.lam "x" (.nonempty (.var "x"))) (.arr .num .num)) (.lit 1))))
    (.arr .num .num)

def shadowActions : List Action :=
  [.ascribe (.arr .num .num), .lam "x", .var "x", .plus, .app, .lit 1,
   .move .parent, .move (.child .first), .lam "x", .move .parent, .move .parent,
   .setType (.arr .num .num), .move (.child .first), .move (.child .first), .var "x", .wrap]

def shadowState : State := run [] .syn { client := ⟨true⟩ } (shadowActions.map Event.edit)
example : shadowState.zipper.erase = shadow := by decide
example : shadowState.version = 10 := by decide
theorem shadow_trace_invariant : Invariant [] .syn shadowState :=
  reactive_invariant ⟨rfl, trivial⟩ _

def requested : State := update [] .syn shadowState (.definition ⟨0, 25⟩)
def pending : Pending := requested.pending.getD ⟨999, ⟨⟨""⟩, ⟨0, 0⟩⟩, 0, .hole, {}⟩
def response : Reply := serve pending
def accepted : State := update [] .syn requested (.response response)
def afterEdit : State := update [] .syn requested (.edit .erase)
def stale : State := update [] .syn afterEdit (.response response)

example : synth [] shadow = some (.arr .num .num) := by decide
example : (definition shadowState.uri shadow ⟨0, 9⟩).map (·.targetSelectionRange.start.character) =
    some 3 := by decide
example : (definition shadowState.uri shadow ⟨0, 25⟩).map (·.targetSelectionRange.start.character) =
    some 19 := by decide
example : accepted.status = .accepted := by decide
example : stale.status = .stale ∧ stale.navigation = none := by decide

/- A still well-formed target to the wrong (outer) binder is rejected. -/
def forged : Reply := ⟨pending.id, answer shadowState.client shadowState.uri shadow ⟨0, 9⟩⟩
example : (update [] .syn requested (.response forged)).status = .invalidResponse := by decide

/- Cursor movement is not a source edit, so an in-flight response remains valid. -/
def moved : State := update [] .syn requested (.edit (.move .parent))
example : moved.status = .moved := by decide
example : moved.version = requested.version := by decide
example : (update [] .syn moved (.response response)).status = .accepted := by decide

/- A superseding request gets a fresh id, so an older reply cannot be misattributed. -/
def superseded : State := update [] .syn requested (.definition ⟨0, 9⟩)
example : (update [] .syn superseded (.response response)).status = .unexpected := by decide

example : utf16Length "😀" = 2 := by decide
example : utf16Length (nameText "😀") = 4 := by decide
example : render (.var "a\nb") = "\"a\\nb\"" := by decide
example : (definition "file:///unicode.hz" (.lam "😀" (.var "😀")) ⟨0, 8⟩).map
    (·.targetSelectionRange.end.character) = some 6 := by decide

example : answer {} "file:///example.hz" .hole ⟨0, 0⟩ = .null := by decide
example : answer {} shadowState.uri shadow ⟨0, 24⟩ = .null := by decide -- hole delimiter
example : answer {} shadowState.uri shadow ⟨1, 25⟩ = .null := by decide -- wrong line
example : answer {} shadowState.uri shadow ⟨0, 28⟩ = .null := by decide -- exclusive end
example : synth [] (.nonempty (.var "free")) = none := by decide
example : synth [] (.nonempty (.lam "x" (.var "x"))) = none := by decide
example : synth [] (.app (.lit 3) (.lit 3)) = none := by decide
/- Paper-componentwise consistency, including the two upstream OCaml discrepancies. -/
example : consistent (.arr .num .num) (.arr (.arr .num .num) (.arr .num .num)) = false := by decide
example : consistent (.arr .num (.arr .num .num)) (.arr .num (.arr .hole .num)) = true := by decide
example : (update [] .syn { server := ⟨false, .utf16⟩ } (.definition ⟨0, 0⟩)).status =
    .unsupported := by decide
example : (answer {} shadowState.uri shadow ⟨0, 25⟩) = .locations
    [⟨shadowState.uri, ⟨⟨0, 19⟩, ⟨0, 22⟩⟩⟩] := by decide

theorem examples_reactive_invariant : Invariant incrCtx .syn edited :=
  reactive_invariant initial_invariant _

def renderFrame (inside : String) : Frame → String
  | .lam x => "(λ" ++ nameText x ++ ". " ++ inside ++ ")"
  | .appL a => "(" ++ inside ++ " " ++ render a ++ ")"
  | .appR f => "(" ++ render f ++ " " ++ inside ++ ")"
  | .plusL r => "(" ++ inside ++ " + " ++ render r ++ ")"
  | .plusR l => "(" ++ render l ++ " + " ++ inside ++ ")"
  | .asc t => "(" ++ inside ++ " : " ++ renderTy t ++ ")"
  | .nonempty => "⦇" ++ inside ++ "⦈"

def renderCursor (z : ZExpr) : String :=
  z.path.foldl renderFrame ("⟨" ++ render z.focus ++ "⟩")

def printTrace (Γ : Ctx) (s : State) (actions : List Action) : IO State := do
  match actions with
  | [] => return s
  | a :: rest =>
    let next := update Γ .syn s (.edit a)
    IO.println s!"  {repr a}: {renderCursor next.zipper} [v{next.version}, {repr next.status}]"
    if next.status == .editRejected then throw (IO.userError "edit trace unexpectedly rejected")
    printTrace Γ next rest

def main : IO Unit := do
  IO.println "Hazelnut Figure 2 expression-edit trace:"
  IO.println s!"  start: {renderCursor ({} : State).zipper}"
  let final ← printTrace incrCtx {} incrActions
  unless final.zipper.erase == nestedIncrement do throw (IO.userError "wrong edit result")
  IO.println s!"  synthesized: {repr (synth incrCtx final.zipper.erase)}"
  IO.println "\nConstruct the shadowing example from an empty editor:"
  let built ← printTrace [] { client := ⟨true⟩ } shadowActions
  unless built.zipper.erase == shadow do throw (IO.userError "wrong shadowing edit result")
  IO.println "\nLexical go-to-definition (UTF-16 columns, half-open ranges):"
  IO.println (render shadow)
  IO.println s!"  outer reference @9: {repr (definition shadowState.uri shadow ⟨0, 9⟩)}"
  IO.println s!"  shadowed reference inside nonempty hole @25: {repr response.result}"
  IO.println s!"  response accepted: {repr accepted.status}"
  IO.println s!"  view selects binder: {repr (view accepted).selection}"
  IO.println s!"  well-formed but wrong binder: {repr (update [] .syn requested (.response forged)).status}"
  IO.println s!"  edit to v{afterEdit.version}, then old response: {repr stale.status}"
  IO.println s!"  cursor-only move, then response: {repr (update [] .syn moved (.response response)).status}"
  unless accepted.status == .accepted && stale.status == .stale && stale.navigation.isNone do
    throw (IO.userError "response lifecycle failed")
  IO.println s!"  empty hole: {repr (answer {} shadowState.uri .hole ⟨0, 0⟩)}"
  IO.println s!"  client without linkSupport: {repr (answer {} shadowState.uri shadow ⟨0, 25⟩)}"
  IO.println s!"  UTF-16 width of 😀: {utf16Length "😀"}"
  IO.println "All executable examples passed."

end EditorExamples

def main : IO Unit := EditorExamples.main
