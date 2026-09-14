# link-farm-mods.nix — Build packwiz mod JARs into a symlink farm using linkFarm.
# Mirrors the server's packwizSymlinks logic: applies patches.nix and extra-mods.nix
# so the headless build produces the same jars the server actually ships.
#
# Usage: nix-build -E 'import ./link-farm-mods.nix { repo = /path/to/repo; packName = "AllTheTech"; }'
{ repo, packName }:

let
  pkgs = import <nixpkgs> { config.allowUnfree = true; };
  flake = builtins.getFlake (toString repo);
  packwiz2nix = flake.inputs.packwiz2nix;

  packDir = "${repo}/modules/nixos/minecraft-server/modpacks/${packName}";
  checksumsPath = "${packDir}/checksums.json";
  modsDir = "${packDir}/mods";

  # Fixed-output derivations for every mod in checksums.json
  # (map from "<mod>.pw.toml" → store path)
  mods = packwiz2nix.lib.mkPackwizPackages pkgs checksumsPath;

  # Filter out client-only mods (side = "client")
  serverMods = pkgs.lib.filterAttrs
    (n: _:
      let pw = "${modsDir}/${n}";
      in !builtins.pathExists pw
        || ((builtins.fromTOML (builtins.readFile pw)).side or "both") != "client"
    )
    mods;

  # Convert to link keys: "mods/<checksums.json key with .pw.toml → .jar>"
  # This matches the key format used by patches.nix and extra-mods.nix.
  baseModLinks = packwiz2nix.lib.mkModLinks serverMods;

  # Apply build-time jar patches from <pack>/patches.nix (same as packwizSymlinks).
  # These fix dependency version ranges that would otherwise crash the server.
  patchedMods =
    if builtins.pathExists "${packDir}/patches.nix" then
      import "${packDir}/patches.nix"
        {
          inherit mods pkgs;
          patchJar = import "${repo}/modules/nixos/minecraft-server/modpacks/patch-jar.nix" { inherit pkgs; };
          buildModSource = import "${repo}/modules/nixos/minecraft-server/modpacks/build-mod-source.nix" { inherit pkgs; };
        }
    else
      { };

  # Apply extra local mods from <pack>/extra-mods.nix (same as packwizSymlinks).
  # These add mods not in checksums.json (e.g. ponder, dt-tree-water-cleanup).
  extraMods =
    if builtins.pathExists "${packDir}/extra-mods.nix" then
      import "${packDir}/extra-mods.nix"
        {
          inherit mods pkgs;
          buildModSource = import "${repo}/modules/nixos/minecraft-server/modpacks/build-mod-source.nix" { inherit pkgs; };
        }
    else
      { };

  # Merge: base mod links + patched overrides + extra mods
  # patchedMods overrides baseModLinks (same key format: "mods/<name>.jar")
  finalMods = baseModLinks // patchedMods // extraMods;

  # Build the linkFarm entries: strip the "mods/" prefix for linkFarm names
  entries = map
    (key: {
      name = pkgs.lib.removePrefix "mods/" key;
      path = finalMods.${key};
    })
    (builtins.attrNames finalMods);

in
pkgs.linkFarm "allthetech-mods" entries
