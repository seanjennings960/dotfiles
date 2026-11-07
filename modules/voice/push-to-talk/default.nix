{
  lib,
  stdenv,
  makeWrapper,
  python3,
  microphone,
  transcribe,
}:

stdenv.mkDerivation {
  pname = "devchain-push-to-talk";
  version = "0.1.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./hotkey.m
      ./paste.m
      ./push_to_talk.py
    ];
  };
  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ python3.pkgs.pytest ];
  doCheck = true;

  buildPhase = ''
    runHook preBuild
    $CC -Wall -Wextra -Werror -fobjc-arc hotkey.m -o ptt-hotkey \
      -framework Foundation -framework IOKit
    $CC -Wall -Wextra -Werror -fobjc-arc paste.m -o ptt-paste \
      -framework AppKit -framework ApplicationServices
    runHook postBuild
  '';

  checkPhase = ''
    runHook preCheck
    PUSH_TO_TALK_SOURCE="$PWD/push_to_talk.py" \
      ${python3.interpreter} -m pytest -q -p no:cacheprovider ${../../../tests/test_push_to_talk.py}
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 ptt-hotkey "$out/libexec/ptt-hotkey"
    install -Dm755 ptt-paste "$out/libexec/ptt-paste"
    install -Dm644 push_to_talk.py "$out/libexec/push_to_talk.py"
    makeWrapper ${python3.interpreter} "$out/bin/push-to-talk" \
      --add-flags "$out/libexec/push_to_talk.py" \
      --set PUSH_TO_TALK_HOTKEY "$out/libexec/ptt-hotkey" \
      --set PUSH_TO_TALK_MICROPHONE "${microphone}/bin/microphone" \
      --set PUSH_TO_TALK_PASTE "$out/libexec/ptt-paste" \
      --prefix PATH : ${lib.makeBinPath [ transcribe ]}
    runHook postInstall
  '';

  meta = {
    description = "Global hold-to-record hotkey with local transcription to stdout";
    mainProgram = "push-to-talk";
    platforms = lib.platforms.darwin;
  };
}
