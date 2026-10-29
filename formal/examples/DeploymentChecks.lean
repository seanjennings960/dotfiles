import Formal.Nix
import Formal.Deployment

/- Run with `lake env lean --run examples/DeploymentChecks.lean`. The anonymous
examples and general theorems are kernel-checked while building the two modules. -/
def main : IO Unit := do
  IO.println "NixLang fragment:"
  for (name, result) in Formal.Nix.Examples.report do
    IO.println s!"  {name}: {reprStr result}"
  IO.println "Multi-user deployment after rollback, history pruning and GC:"
  for (name, result) in Formal.Deployment.Examples.report do
    IO.println s!"  {name}: {result}"

#print axioms Formal.Nix.interpreter_correspondence
#print axioms Formal.Nix.divergence_correspondence
#print axioms Formal.Deployment.transition_invariant
#print axioms Formal.Deployment.executeAll_preserves
#print axioms Formal.Deployment.Examples.collected_invariant
