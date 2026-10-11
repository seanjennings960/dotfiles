import DevCreation

open DevCreation DevCreation.Scenarios

private def traceDemo : IO Unit := do
  let mut state := initial
  for input in happyPath do
    IO.println s!"input: {repr input}"
    match step state input with
    | .error error => IO.println s!"  rejected: {repr error}"
    | .ok (next, effects) =>
        for effect in effects do
          IO.println s!"  effect: {repr effect}"
        state := next
  IO.println s!"outcome: {repr state.lastOutcome}"
  IO.println s!"published artifacts: {state.store.length}"

def main (args : List String) : IO UInt32 := do
  match args with
  | [] =>
      let mut failed := false
      for scenario in scenarios do
        if scenario.passes then
          IO.println s!"PASS {scenario.name}"
        else
          IO.println s!"FAIL {scenario.name}"
          failed := true
      IO.println s!"{scenarios.length} executable scenarios; proofs checked by lake build."
      return if failed then 1 else 0
  | ["trace"] =>
      traceDemo
      return 0
  | _ =>
      IO.eprintln "Usage: lake exe creation_model [trace]"
      return 2
