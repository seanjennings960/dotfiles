{ lib, stdenv }:

stdenv.mkDerivation {
  pname = "devchain-microphone";
  version = "0.1.0";
  dontUnpack = true;

  buildPhase = ''
    runHook preBuild
    $CC -Wall -Wextra -Werror -fobjc-arc ${./microphone.m} -o microphone \
      -Wl,-sectcreate,__TEXT,__info_plist,${./microphone.plist} \
      -framework Foundation -framework AVFoundation
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 microphone "$out/bin/microphone"
    runHook postInstall
  '';

  meta = {
    description = "Record the default macOS microphone as 16 kHz mono PCM WAV";
    mainProgram = "microphone";
    platforms = lib.platforms.darwin;
  };
}
