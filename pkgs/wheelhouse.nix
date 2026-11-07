{ fetchurl, linkFarm }:

# Universal wheels shared by both supported platforms. Update this manifest
# alongside Python dependency changes; every download is verified by Nix.
linkFarm "dev-python-wheels" (
  map (wheel: {
    name = builtins.baseNameOf wheel.url;
    path = fetchurl wheel;
  }) (builtins.fromJSON (builtins.readFile ./wheels.json))
)
