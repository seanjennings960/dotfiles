{
  lib,
  stdenv,
  ocamlPackages,
}:

stdenv.mkDerivation {
  pname = "devchain-markdown-preview";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = ../tools/markdown_preview.ml;
  };

  nativeBuildInputs = [
    ocamlPackages.ocaml
    ocamlPackages.findlib
  ];
  buildInputs = [ ocamlPackages.cmarkit ];
  strictDeps = true;

  buildPhase = ''
    runHook preBuild
    ocamlfind ocamlopt -package cmarkit -linkpkg \
      -o devchain-markdown tools/markdown_preview.ml
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 devchain-markdown "$out/bin/devchain-markdown"
    runHook postInstall
  '';

  meta = {
    description = "Serverless Markdown renderer using Cmarkit's safe HTML mode";
    mainProgram = "devchain-markdown";
    inherit (ocamlPackages.cmarkit.meta) platforms;
  };
}
