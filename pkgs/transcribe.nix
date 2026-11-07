{
  lib,
  writeShellApplication,
  fetchurl,
  whisper-cpp,
}:

let
  model = fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-base.en.bin";
    sha256 = "a03779c86df3323075f5e796cb2ce5029f00ec8869eee3fdfb897afe36c6d002";
  };
in
writeShellApplication {
  name = "transcribe";
  runtimeInputs = [ whisper-cpp ];
  text = ''
    if [ "$#" -ne 1 ]; then
      echo 'Usage: transcribe AUDIO.wav' >&2
      exit 2
    fi
    model="''${WHISPER_MODEL:-${model}}"
    if [ ! -r "$model" ] || [ ! -r "$1" ]; then
      echo 'transcribe: model or audio file is not readable' >&2
      exit 1
    fi
    exec whisper-cli --model "$model" --file "$1" \
      --language "''${WHISPER_LANGUAGE:-en}" --no-timestamps --no-prints
  '';
  meta.description = "Local Whisper transcription to stdout with a pinned base.en model";
}
