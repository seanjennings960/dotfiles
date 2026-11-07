# Toolchain summary

- Platform: `aarch64-darwin`.
- Reference installation binary: `/nix/var/nix/profiles/default/bin/nix`.
- nixpkgs revision: `718f670e845328e9c2cecdd832835712b2cbd065` (`nixos-26.05`).
- Lean version: **4.29.1**; `lean-toolchain` pins `leanprover/lean4:v4.29.1`.
- Lean executable: `/nix/store/jcaahg1daq98ihbjqmmwnl07wl5p4lfa-lean4-4.29.1/bin/lean`.
- Lake executable: `/nix/store/jcaahg1daq98ihbjqmmwnl07wl5p4lfa-lean4-4.29.1/bin/lake`.
- Realized and verified: `lean --version` reports 4.29.1; `lake --version`
  reports Lake 5.0.0-src+v4.29.1 (Lean 4.29.1).
- Reproducible shell: `/nix/var/nix/profiles/default/bin/nix-shell formal/shell.nix`.

Reference tool work is recorded in `TOOLS.md` and `reference/`.

Final reference status:

- Agda 2.8.0: the complete pinned upstream `all.agda` passes.
- OCaml 5.4.1: upstream semantics compiles and 11 behavioral checks pass;
  a separate paper-consistency audit exposes three upstream bugs (exit 1).
- Isabelle2025-2: original source fails at legacy `case_tac const` (line 171);
  a fresh copy with only the `delta_safe` proof modernized passes the complete
  theory, including `type_safety`. Original source hash is unchanged.
