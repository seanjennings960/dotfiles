# Actual Nix behavior. These are integration fixtures, not extracted Lean code.
let
  bad = throw "fixture-forced";
  omega = (x: x x) (x: x x);
  attempt = e: (builtins.tryEval e).success;
in {
  checks = {
    lexicalOverWith = (let x = 7; in with { x = 99; }; x) == 7;
    innerLetOverWith = (with { x = 7; }; let x = 42; in x) == 42;
    innerWithWins = (with { x = 7; }; with { x = 42; }; x) == 42;
    lambdaOverWith = ((x: with { x = 99; }; x) 42) == 42;
    innerLambdaRebinds = (let x = 7; in (x: x) 42) == 42;
    savedClosure = (let x = 7; y = x; in let x = 99; in y) == 7;
    unusedArgument = ((unused: 42) omega) == 42;
    lazyFieldSelection = { broken = omega; answer = 42; }.answer == 42;
    recursiveLet = (let y = x; x = 42; in y) == 42;
    recursiveAttrs = (rec { y = x; x = 42; }).y == 42;
    inheritedOuter = (let x = 7; in (rec { inherit x; y = x; }).y) == 7;
    recursiveDefaults = ({ a ? b, b ? 42 }: a) {} == 42;
    suppliedDefaultBreaksCycle = ({ a ? b, b ? a }: a) { b = 42; } == 42;
    unusedRecursiveDefault = ({ a ? a }: true) {};
    recursiveFunctionDefault =
      ({ even ? (n: if n == 0 then true else !(even (n - 1))) }: even 8) {};
    seqShallowAttrs = builtins.seq { nested = bad; } true;
    seqShallowList = builtins.seq [ bad ] true;
    deepSeqForcesAttrs = !(attempt (builtins.deepSeq { nested = { x = bad; }; } true));
    deepSeqForcesList = !(attempt (builtins.deepSeq [ [ bad ] ] true));
    deepSeqDoesNotEnterLambda = builtins.deepSeq (x: bad) true;
    seqForcesOuter = !(attempt (builtins.seq bad true));
    differentDomainSizeSkipsValues = !({ a = bad; } == {});
    disjointSingletonDomainsSkipValues = !({ a = bad; } == { b = bad; });
    equalDomainsForceValues = !(attempt ({ a = bad; } == { a = 1; }));
    actualNixUnusedWith = with omega; true;
    actualNixSharedCycle = builtins.deepSeq (let x = { self = x; }; in x) true;
  };

  # NixLang checks the entire domain before any values. Real Nix's result can
  # depend on the surrounding code: this fixture returned successful false,
  # while the runner's isolated version of the same comparison caught a throw.
  # Keep this as an observation, not an assertion of equivalence.
  observations.sameSizeDomainMismatch = builtins.tryEval
    ({ a = bad; b = 1; } == { a = bad; c = 2; });
  # The modeled NixLang fragment faults here; native Nix returns false.
  observations.functionEquality = (x: x) == (x: x);
}
