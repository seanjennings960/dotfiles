{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  zlib,
}:

let
  version = "2.1.4";
  platforms = {
    aarch64-darwin = {
      target = "darwin-arm64";
      hash = "sha512-QwjyvovTdT0gFi5rxUyPVlYePIe3ELduR9olu+KJWe089XVIDOTMhxylBe/ZGIpvoXHYo6bp2NskIiqCFAEXsw==";
    };
    aarch64-linux = {
      target = "linux-arm64";
      hash = "sha512-drw0LWMG0niaE94ePXm1h7qjFBZZRcSZD3gact3hx3OYPXesp7xrOt0bn3sicYNUN6fojERrDKR6jYrXmZX+rA==";
    };
  };
  platform = platforms.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "opencode";
  inherit version;
  src = fetchurl {
    url = "https://registry.npmjs.org/@opencode/cli-${platform.target}/-/cli-${platform.target}-${version}.tgz";
    inherit (platform) hash;
  };

  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.isLinux [
    stdenv.cc.cc.lib
    zlib
  ];
  dontStrip = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/opencode "$out/bin/opencode"
    runHook postInstall
  '';

  meta = {
    description = "OpenCode V2 coding agent";
    homepage = "https://opencode.ai/v2/";
    mainProgram = "opencode";
    platforms = builtins.attrNames platforms;
  };
}
