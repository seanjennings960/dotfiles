import DevCreation.Proofs

namespace DevCreation.Scenarios

def mcr : RegistryId := ⟨.oci, "mcr"⟩
def ubuntu : RegistryId := ⟨.apt, "ubuntu"⟩
def pypi : RegistryId := ⟨.pypi, "pypi"⟩
def privatePyPI : RegistryId := ⟨.pypi, "private"⟩

/-- Illustrative identities, not real package digests or a production lock. -/
def base : Artifact := ⟨mcr, "devcontainers/base", "ubuntu-24.04", "linux/arm64", "base-digest"⟩
def python : Artifact := ⟨ubuntu, "python3", "3.12.3", "linux/arm64", "python-digest"⟩
def click : Artifact := ⟨pypi, "click", "8.3.3", "py3-none-any", "click-digest"⟩

def mcrOrigin : Origin := "https://mcr.microsoft.com:443"
def aptOrigin : Origin := "https://ports.ubuntu.com:443"
def pypiOrigin : Origin := "https://pypi.org:443"
def filesOrigin : Origin := "https://files.pythonhosted.org:443"
def otherOrigin : Origin := "https://unlisted.example:443"

def grant : Grant :=
  [⟨mcr, [mcrOrigin]⟩, ⟨ubuntu, [aptOrigin]⟩, ⟨pypi, [pypiOrigin, filesOrigin]⟩]

def lock : Lock := ⟨[base, python, click]⟩
def baseLock : Lock := ⟨[base]⟩

def stateAfter (inputs : List Input) : State := (execute initial inputs).1
def effectsAfter (inputs : List Input) : List Effect := (execute initial inputs).2

def fetchBase : List Input :=
  [.beginFetch baseLock grant, .request base mcrOrigin,
   .received 0 0 base.digest, .published 0 0, .finishFetch 0]

def fetchAll : List Input :=
  [.beginFetch lock grant,
   .request base mcrOrigin, .received 0 0 base.digest, .published 0 0,
   .request python aptOrigin, .received 0 1 python.digest, .published 0 1,
   .request click pypiOrigin, .redirected 0 2 filesOrigin,
   .received 0 3 click.digest, .published 0 3, .finishFetch 0]

def happyPath : List Input :=
  fetchAll ++ [.beginCreate lock, .buildFinished 1, .setupFinished 1]

def downloadingClick : State :=
  stateAfter [.beginFetch lock grant, .request click pypiOrigin]

def uncommittedClick : State :=
  stateAfter [.beginFetch lock grant, .request click pypiOrigin, .received 0 0 click.digest]

def building : State := stateAfter (fetchAll ++ [.beginCreate lock])

def isDownload : Effect → Bool
  | .download .. => true
  | _ => false

def rejected (state : State) (input : Input) (error : Error) : Bool :=
  match step state input with
  | .error actual => actual == error && applyInput state input == (state, [])
  | .ok _ => false

structure Scenario where
  name : String
  checks : List Bool

def Scenario.passes (scenario : Scenario) : Bool := scenario.checks.all id

def scenarios : List Scenario := [
  { name := "OCI/APT/PyPI acquisition, allowed redirect, then offline build and setup"
    checks := [
      (stateAfter happyPath).phase == .idle,
      (stateAfter happyPath).lastOutcome == some (1, .created),
      (stateAfter happyPath).nextRun == 2,
      complete (stateAfter happyPath).store lock,
      ((effectsAfter happyPath).filter isDownload).length == 4,
      (effectsAfter happyPath).contains (.build 1 lock .none),
      (effectsAfter happyPath).contains (.setup 1 lock .none)] },
  { name := "cold creation rejects missing inputs without acquiring anything"
    checks := [rejected initial (.beginCreate lock) .missingInputs,
      effectsAfter [.beginCreate lock] == []] },
  { name := "unpinned inputs reject both fetch and creation"
    checks := [
      rejected initial (.beginFetch ⟨[{ click with digest := "" }]⟩ grant) .invalidLock,
      rejected initial (.beginCreate ⟨[{ base with version := "" }]⟩) .invalidLock] },
  { name := "requests require both the locked artifact and its registry grant"
    checks := [
      rejected (stateAfter [.beginFetch lock []]) (.request click pypiOrigin) .originDenied,
      rejected (stateAfter [.beginFetch baseLock grant]) (.request click pypiOrigin) .notLocked,
      rejected (stateAfter [.beginFetch lock grant]) (.request click otherOrigin) .originDenied] },
  { name := "same-ecosystem private registries do not inherit the public registry grant"
    checks := [
      rejected (stateAfter [.beginFetch ⟨[{ click with registry := privatePyPI }]⟩ grant])
        (.request { click with registry := privatePyPI } pypiOrigin) .originDenied] },
  { name := "unlisted redirects cannot broaden a grant"
    checks := [rejected downloadingClick (.redirected 0 0 otherOrigin) .originDenied,
      (applyInput downloadingClick (.redirected 0 0 filesOrigin)).2 ==
        [.download 0 1 ⟨click, filesOrigin⟩]] },
  { name := "digest mismatch cannot publish an artifact"
    checks := [
      rejected downloadingClick (.received 0 0 "incorrect-digest") .digestMismatch,
      rejected downloadingClick (.published 0 0) .wrongPhase,
      downloadingClick.store == []] },
  { name := "verified bytes remain unavailable until publication is acknowledged"
    checks := [
      uncommittedClick.store == [],
      rejected uncommittedClick (.finishFetch 0) .wrongPhase,
      (applyInput uncommittedClick (.published 0 0)).1.store == [⟨⟨click, pypiOrigin⟩, click.digest⟩],
      (applyInput uncommittedClick (.backendFailed 0)).1.store == []] },
  { name := "partial fetch failure keeps committed artifacts and drops its grant"
    checks := [
      let failed := stateAfter (fetchAll.take 4 ++ [.backendFailed 0])
      available failed.store base && !available failed.store click &&
        failed.phase == .idle && failed.lastOutcome == some (0, .failed),
      let failed := stateAfter (fetchAll.take 4 ++ [.backendFailed 0])
      rejected failed (.request click pypiOrigin) .wrongPhase,
      let failed := stateAfter (fetchAll.take 4 ++ [.backendFailed 0])
      rejected (applyInput failed (.beginFetch lock [])).1 (.request click pypiOrigin) .originDenied] },
  { name := "an incomplete fetch cannot report successful completion"
    checks := [rejected (stateAfter (fetchAll.take 4)) (.finishFetch 0) .missingInputs] },
  { name := "local reuse needs no acquisition grant"
    checks := [
      let reused := execute (stateAfter fetchBase)
        [.beginFetch baseLock [], .request base otherOrigin, .finishFetch 1]
      reused.2 == [] && reused.1.lastOutcome == some (1, .fetched),
      let created := execute (stateAfter fetchBase)
        [.beginCreate baseLock, .buildFinished 1, .setupFinished 1]
      created.1.lastOutcome == some (1, .created) && !created.2.any isDownload] },
  { name := "operations cannot overlap or evict leased inputs"
    checks := [
      rejected building (.beginFetch lock grant) .wrongPhase,
      rejected building (.beginCreate lock) .wrongPhase,
      rejected building (.evict base) .wrongPhase,
      rejected building (.request click pypiOrigin) .wrongPhase,
      rejected downloadingClick (.beginCreate lock) .wrongPhase] },
  { name := "callbacks must match both the active run and lifecycle phase"
    checks := [
      rejected downloadingClick (.received 99 0 click.digest) .wrongRun,
      rejected downloadingClick (.published 0 0) .wrongPhase,
      rejected building (.buildFinished 0) .wrongRun,
      rejected building (.backendFailed 0) .wrongRun,
      rejected building (.setupFinished 1) .wrongPhase,
      rejected (applyInput building (.buildFinished 1)).1 (.buildFinished 1) .wrongPhase] },
  { name := "stale transfers cannot acknowledge a redirected or subsequent download"
    checks := [
      let redirected := (applyInput downloadingClick (.redirected 0 0 filesOrigin)).1
      rejected redirected (.received 0 0 click.digest) .wrongTransfer,
      let publishingPython := stateAfter (fetchAll.take 6)
      rejected publishingPython (.published 0 0) .wrongTransfer,
      let publishingPython := stateAfter (fetchAll.take 6)
      !available publishingPython.store python && available publishingPython.store base] },
  { name := "creation failure retains inputs and emits no automatic retry or fetch"
    checks := [
      let failed := applyInput building (.backendFailed 1)
      failed.1.phase == .idle && failed.1.lastOutcome == some (1, .failed) &&
        failed.1.store == building.store && failed.2 == []] },
  { name := "idle eviction makes later creation fail rather than fetch"
    checks := [
      let evicted := applyInput (stateAfter happyPath) (.evict base)
      !available evicted.1.store base && evicted.2 == [] &&
        rejected evicted.1 (.beginCreate lock) .missingInputs] },
  { name := "changed digest or target platform cannot reuse the old artifact identity"
    checks := [
      rejected (stateAfter fetchBase) (.beginCreate ⟨[{ base with digest := "new-digest" }]⟩)
        .missingInputs,
      rejected (stateAfter fetchBase) (.beginCreate ⟨[{ base with platform := "linux/amd64" }]⟩)
        .missingInputs] }
]

set_option maxRecDepth 8192 in
/-- These concrete scenario expectations are also checked by the Lean kernel. -/
example : scenarios.all Scenario.passes = true := by decide

end DevCreation.Scenarios
