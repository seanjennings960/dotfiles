import Formal.Nix
import Formal.Deployment
import Lean.Util.CollectAxioms
import Lean.Elab.Command

/- Audit all declarations in both modules, including generated helpers and
anonymous checked examples. No declared assumptions, choice, or native proofs. -/
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let mut checked := 0
  let mut used : Array Name := #[]
  for (name, _) in env.constants.toList do
    if let some idx := env.getModuleIdxFor? name then
      let moduleName := env.header.moduleNames[idx.toNat]!
      if #[`Formal.Nix, `Formal.Deployment].contains moduleName then
        for ax in (← collectAxioms name) do
          unless #[`propext, `Quot.sound].contains ax do
            throwError "{name} depends on forbidden axiom {ax}"
          unless used.contains ax do used := used.push ax
        checked := checked + 1
  if checked == 0 then throwError "No Nix/deployment declarations were audited"
  logInfo m!"PASS: audited {checked} Nix/deployment declarations; axioms used: {used}"
