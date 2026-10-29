import Formal
import Lean.Util.CollectAxioms
import Lean.Elab.Command

/-! Audit every declaration imported from a project module, including private
    helpers. Only constructive foundational axioms pass. -/
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let mut checked := 0
  let mut used : Array Name := #[]
  for (name, _) in env.constants.toList do
    if let some idx := env.getModuleIdxFor? name then
      let moduleName := env.header.moduleNames[idx.toNat]!
      if `Formal |>.isPrefixOf moduleName then
        let axioms ← collectAxioms name
        for ax in axioms do
          unless #[`propext, `Quot.sound].contains ax do
            throwError "{name} depends on forbidden axiom {ax}"
          unless used.contains ax do used := used.push ax
        checked := checked + 1
  if checked == 0 then throwError "No project declarations were audited"
  logInfo m!"PASS: audited {checked} project declarations; axioms used: {used}"
