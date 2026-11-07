# Derivation plans; evaluation does not run builders or change profiles.
# deployment-check.py --native additionally builds them in a disposable store.
# Explicit tools avoid <nixpkgs>, network fetches, and implicit host search paths.
{ system ? builtins.currentSystem
, shell ? "/bin/sh"
, mkdir ? "/bin/mkdir"
, cat ? "/bin/cat"
, chmod ? "/bin/chmod"
}:
let
  mk = name: dependencies: text:
    builtins.derivation {
      inherit name system;
      builder = shell;
      args = [ "-eu" "-c" ''
        ${mkdir} -p "$out/bin"
        printf '%s\n' "$message" > "$out/message"
        printf '%s\n' "$references" > "$out/references"
        printf '#!%s\nset -eu\n' "$builder" > "$out/bin/run"
        printf 'printf "%%s\\n" "%s"\n' "$message" >> "$out/bin/run"
        for reference in $references; do
          printf '%s "%s/message"\n' '${cat}' "$reference" >> "$out/bin/run"
        done
        ${chmod} +x "$out/bin/run"
      '' ];
      message = text;
      references = builtins.concatStringsSep "\n" (map (d: d.outPath) dependencies);
    };
  runtime = mk "formal-runtime-v1" [] "shared runtime";
  aliceV1 = mk "formal-alice-editor-v1" [ runtime ] "Alice editor 1";
  aliceV2 = mk "formal-alice-editor-v2" [ runtime ] "Alice editor 2";
  bob = mk "formal-bob-analysis" [ runtime ] "Bob analysis";
  # Avoid the special `outPath` attribute name: JSON coercion treats an attrset
  # containing it as a path-like string instead of preserving the record.
  inspect = d: { derivationPath = d.drvPath; outputPath = d.outPath; };
in {
  # Evaluating the derivation's output path instantiates its .drv, but does not
  # build it. Input contexts carry the shared dependency into both user plans.
  plans = {
    runtime = inspect runtime;
    aliceV1 = inspect aliceV1;
    aliceV2 = inspect aliceV2;
    bob = inspect bob;
  };
  users = {
    alice = { retained = [ aliceV1.outPath aliceV2.outPath ]; desired = aliceV2.outPath; };
    bob = { retained = [ bob.outPath ]; desired = bob.outPath; };
  };
  assumptions = {
    evaluationOnlyCreatesPlans = true;
    hostToolsAreExplicitButNotHermetic = true;
    realProfilesTouched = false;
  };
}
