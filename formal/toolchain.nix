# All tools share this immutable nixpkgs revision and unpacked-source hash.
{ system ? builtins.currentSystem }:
let
  source = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/718f670e845328e9c2cecdd832835712b2cbd065.tar.gz";
    sha256 = "0jw6fc1f4p6hnpmnp6c5ga5a0xlfbba5245xnx37m1rcixd43vhi";
  };
  pkgs = import source { inherit system; config = {}; overlays = []; };
in {
  inherit pkgs source;
  inherit (pkgs) lean4 agda ocaml isabelle;
}
