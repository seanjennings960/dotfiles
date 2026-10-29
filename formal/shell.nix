{ system ? builtins.currentSystem, references ? false }:
let
  tools = import ./toolchain.nix { inherit system; };
in tools.pkgs.mkShell {
  name = "formal-lean-4.29.1";
  packages = [ tools.lean4 tools.pkgs.python3 ]
    ++ tools.pkgs.lib.optionals references [ tools.agda tools.ocaml tools.isabelle ];
}
