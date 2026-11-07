{ lib, stdenv }:

stdenv.mkDerivation {
  pname = "devchain-microphone";
  version = "0.1.0";
  dontUnpack = true;

  buildPhase = ''
    runHook preBuild
    $CC -Wall -Wextra -Werror -fobjc-arc ${./microphone.m} -o microphone \
      -Wl,-sectcreate,__TEXT,__info_plist,${./microphone.plist} \
      -framework Foundation -framework AVFoundation -framework AudioToolbox -framework CoreAudio
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 microphone "$out/bin/microphone"
    runHook postInstall
  '';

  meta = {
    description = "Discover and record macOS microphones as 16 kHz mono PCM WAV";
    mainProgram = "microphone";
    platforms = lib.platforms.darwin;
  };
}
