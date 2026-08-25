# =============================================================================
# packwiz.nix — Minecraft modpack tooling at the flake level
# =============================================================================
# Purpose: Expose the packwiz CLI and per-modpack checksum generators for the
#          packwiz2nix workflow. Modpacks live in
#          modules/nixos/minecraft-server/modpacks/<name>/ and are authored with
#          the packwiz CLI; packwiz2nix converts them into Nix fixed-output
#          derivations consumed by my.services.minecraftServer.
#
# Outputs (perSystem):
#   - packages.packwiz                    → the packwiz CLI
#   - packages."minecraft-modpack-<name>" → built client instance content for a modpack
#   - apps."packwiz-checksums-<modpack>"  → writes <modpack>/checksums.json
#   - apps."modpack-build-<modpack>"      → build + install client content into a Prism
#                                           instance WITHOUT a full system rebuild
#   - apps."modpack-update-<modpack>"     → regenerate checksums, rebuild, reinstall
#
# Usage:
#   cd modules/nixos/minecraft-server/modpacks/AllTheTech
#   nix run .#packwiz -- init            # create the pack
#   nix run .#packwiz -- modrinth add <mod> ...
#   nix run .#packwiz-checksums-AllTheTech  # regenerate checksums.json
#   nix run .#modpack-build-AllTheTech       # install into Prism (no rebuild)
#   nix run .#modpack-update-AllTheTech      # checksums → rebuild → reinstall
#
# The checksum app downloads and hashes every mod at RUNTIME (when `nix run`
# runs it) rather than at eval or build time: packwiz2nix's mkChecksums uses
# builtins.fetchurl without a pinned hash (pure evaluation forbids it) and the
# Nix build sandbox has no network. This keeps `nix flake check` green while
# still producing a committed, reproducible checksums.json.
# =============================================================================

{ config, inputs, lib, ... }:
let
  inherit (lib) concatMap concatStringsSep;
  inherit (inputs) packwiz2nix;
  p2n = packwiz2nix.lib;

  # Default Prism Launcher data dir for the manual CLI apps: the shared
  # `config.minecraft.dataDir` (external media drive) when set, else the
  # launcher's default under $HOME. Keep instances off the system disk.
  defaultDataDir = config.minecraft.dataDir or null;

  # Directory holding packwiz modpacks (one subdir per modpack). Read at eval
  # time so a new modpack directory automatically gets a checksums app.
  # Only subdirectories count — the shared patch-jar.nix helper lives here too
  # and must not be mistaken for a modpack.
  modpacksDir = "${inputs.self}/modules/nixos/minecraft-server/modpacks";
  modpackNames =
    if builtins.pathExists modpacksDir then
      builtins.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir modpacksDir))
    else
      [ ];

  checksumsScript = ./packwiz-checksums.py;

  # Shared instance sync (instance.cfg + mmc-pack.json + mods/internal dirs).
  # Used by the home module's minecraft-instance-<name> service AND the manual
  # CLI apps below so both install identical layouts.
  instanceSyncScript = ./packwiz-instance-sync.py;

  # App that writes <modpack>/checksums.json into the CURRENT WORKING DIRECTORY
  # (run from the modpack dir, matching upstream packwiz2nix behavior).
  # The download+hash happens at RUNTIME (when the app is run), not during
  # eval or build: packwiz2nix's mkChecksums uses builtins.fetchurl (pure-eval
  # forbidden) and build-time fetching would hit the Nix build sandbox (no
  # network). A runtime script keeps `nix flake check` green and lets the user
  # regenerate checksums freely.
  mkChecksumsApp = pkgs: name:
    let
      modsDir = "${modpacksDir}/${name}/mods";
      script = pkgs.writeShellScriptBin "packwiz-checksums-${name}" ''
        ${pkgs.python3}/bin/python3 ${checksumsScript} ${modsDir} > checksums.json
        echo "wrote checksums.json — commit it and rebuild the server"
      '';
    in
    {
      type = "app";
      program = script.outPath + "/bin/packwiz-checksums-${name}";
    };

  # Build a modpack's client content for a Prism Launcher instance.
  #
  # Output layout (installed into <dataDir>/instances/<name>/ by the home
  # module's minecraft-instance-<name> service):
  #   .minecraft/mods/           every mod jar (fixed-output, from checksums.json)
  #   .minecraft/config/         pack internal content (default player configs)
  #   .minecraft/shaderpacks/    client-side shaderpacks (fixed-output fetches)
  #   .minecraft/<kubejs/scripts/datapacks/defaultconfigs>/
  #   meta.json                  { name, minecraft, loaderUid, loaderVersion }
  #                              (from pack.toml; drives instance.cfg/mmc-pack.json)
  #
  # Same checksums.json the server uses — one pack, both sides.
  mkClientInstance = pkgs: name:
    let
      pack = "${modpacksDir}/${name}";
      checksums = "${pack}/checksums.json";
      packToml = builtins.fromTOML (builtins.readFile "${pack}/pack.toml");
      mc = packToml.versions.minecraft;

      # Loader uid:version → Prism component uid. Only one is set per pack.
      loaderUid =
        if packToml.versions ? neoforge then "net.neoforged"
        else if packToml.versions ? fabric then "net.fabricmc.fabric-loader"
        else if packToml.versions ? forge then "net.minecraftforge"
        else if packToml.versions ? quilt then "org.quiltmc.quilt-loader"
        else lib.throw "minecraft-modpack-${name}: no supported loader in pack.toml";
      loaderVersion =
        packToml.versions.neoforge or packToml.versions.fabric or packToml.versions.forge
          or packToml.versions.quilt;

      # Fixed-output derivations for every mod in checksums.json (map from
      # "<mod>.pw.toml" → store path). Shared by mkModLinks below and the
      # per-pack patches.nix (which patches jars built from these same fetches).
      mods =
        if builtins.pathExists checksums then
          p2n.mkPackwizPackages pkgs checksums
        else
          lib.warn "minecraft-modpack-${name}: no checksums.json — client will have no mods. Run .#packwiz-checksums-${name}." { };

      # Build-time jar patches (per-pack patches.nix, if present). Overlays the
      # modLinks result so the client instance ships patched jars exactly like
      # the server (minecraft-server/config.nix packwizSymlinks) — one patch
      # definition, both sides. Keys must match mkModLinks output:
      # "mods/<checksums.json key with .pw.toml → .jar>".
      patchedMods =
        if builtins.pathExists "${pack}/patches.nix" then
          import "${pack}/patches.nix"
            {
              inherit mods pkgs;
              patchJar = import "${modpacksDir}/patch-jar.nix" { inherit pkgs; };
              # Source-level jar patches (build the whole mod from source).
              buildModSource = import "${modpacksDir}/build-mod-source.nix" { inherit pkgs; };
            }
        else
          { };

      modLinks = (p2n.mkModLinks mods) // patchedMods;

      # .minecraft/<dir> symlinks (mirrors packwizStartPre on the server side).
      internalDirs = [ "config" "kubejs" "scripts" "datapacks" "defaultconfigs" ];
      internalLinks = concatStringsSep "\n" (builtins.map
        (d: ''
          if [ -d '${pack}/${d}' ]; then
            ln -s '${pack}/${d}' "$out/.minecraft/${d}"
          fi
        '')
        internalDirs);

      # Game-root file (e.g. a shipped default options.txt) — packwiz installers
      # map a pack-root file 1:1 to the game root, so symlink it into
      # .minecraft/ the same way (mirrors packwizStartPre).
      rootLinks = ''
        if [ -f '${pack}/options.txt' ]; then
          ln -s '${pack}/options.txt' "$out/.minecraft/options.txt"
        fi
      '';

      # Client-side shaderpacks (shaderpacks/*.pw.toml in the pack). Each is a
      # packwiz-tracked file with a pinned [download] URL+hash (usually sha512)
      # and side = "client"; fetch it as a fixed-output derivation — no binary
      # blobs in git — and symlink the zip into .minecraft/shaderpacks/ so Iris
      # lists it in the Shader Packs menu. The server never sees them:
      # checksums.json only covers mods/, and the server's content dirs
      # (packSubdirs in minecraft-server/config.nix) don't include shaderpacks.
      shaderpacksDir = "${pack}/shaderpacks";
      shaderpackMetas = lib.optionalAttrs (builtins.pathExists shaderpacksDir)
        (builtins.listToAttrs
          (map
            (f:
              let
                meta = builtins.fromTOML (builtins.readFile "${shaderpacksDir}/${f}");
              in
              lib.nameValuePair meta.filename meta)
            (builtins.filter (f: lib.hasSuffix ".pw.toml" f)
              (builtins.attrNames (builtins.readDir shaderpacksDir)))));
      shaderpackFetch = meta:
        let
          dl = meta.download;
          hashAttr =
            if dl."hash-format" or "sha512" == "sha512" then { sha512 = dl.hash; }
            else if dl."hash-format" == "sha256" then { sha256 = dl.hash; }
            else if dl."hash-format" == "sha1" then { sha1 = dl.hash; }
            else lib.throw "minecraft-modpack-${name}: unsupported hash-format '${dl."hash-format"}' in ${shaderpacksDir}";
        in
        pkgs.fetchurl ({ url = dl.url; } // hashAttr);
      shaderpackLinksScript = concatStringsSep "\n" (builtins.map
        (filename: ''
          mkdir -p "$out/.minecraft/shaderpacks"
          ln -s '${shaderpackFetch shaderpackMetas.${filename}}' "$out/.minecraft/shaderpacks/${filename}"
        '')
        (builtins.attrNames shaderpackMetas));

      # mods/<fixup>.jar → store path, one symlink per mod.
      modLinksScript = concatStringsSep "\n" (lib.mapAttrsToList
        (target: src: ''
          mkdir -p "$(dirname "$out/.minecraft/${target}")"
          ln -s '${src}' "$out/.minecraft/${target}"
        '')
        modLinks);

      meta = pkgs.writeText "meta.json" (builtins.toJSON {
        inherit name mc loaderUid loaderVersion;
        packName = packToml.name or name;
      });
    in
    pkgs.runCommand "minecraft-modpack-${name}-client" { } ''
      mkdir -p $out/.minecraft
      ${modLinksScript}
      ${internalLinks}
      ${shaderpackLinksScript}
      ${rootLinks}
      cp ${meta} $out/meta.json
    '';

  # CLI: build + install a modpack's client content into a Prism instance
  # WITHOUT a full system rebuild. Usage (from anywhere):
  #   nix run .#modpack-build-<name> [dataDir] [server]
  #   dataDir defaults to config.minecraft.dataDir (external media drive) or
  #   ~/.local/share/PrismLauncher if unset; server (host:port) is optional and
  #   writes [JoinServerOnLaunch] into instance.cfg.
  # The embedded ${pkg} forces the modpack client derivation to build, then the
  # shared sync script installs it — same layout the home module's timer uses.
  mkBuildApp = pkgs: name:
    let
      pkg = mkClientInstance pkgs name;
      script = pkgs.writeShellScriptBin "modpack-build-${name}" ''
        set -euo pipefail
        export PATH=${pkgs.rsync}/bin:${pkgs.coreutils}/bin:$PATH
        DATA_DIR=''${1:-${if defaultDataDir != null then toString defaultDataDir else "$HOME/.local/share/PrismLauncher"}}
        SERVER=''${2:-}
        INST="$DATA_DIR/instances/${name}"
        SRC="${pkg}/.minecraft"
        META="${pkg}/meta.json"
        if [ ! -f "$META" ] || [ ! -d "$SRC" ]; then
          echo "modpack-build-${name}: ${pkg} has no built content" >&2
          exit 1
        fi
        echo "modpack-build-${name}: installing ${pkg} -> $INST"
        ${pkgs.python3}/bin/python3 ${instanceSyncScript} "$INST" "$META" "$SRC" "$SERVER"
        echo "modpack-build-${name}: done — open $INST in Prism Launcher"
      '';
    in
    {
      type = "app";
      program = "${script}/bin/modpack-build-${name}";
    };

  # CLI: full manual update of a modpack — regenerate checksums.json, stage it
  # (the flake only snapshots git-tracked files), rebuild the client content
  # via the flake package and install it into a Prism instance. Must run from
  # the repo root. Usage:
  #   nix run .#modpack-update-<name> [dataDir] [server]
  mkUpdateApp = pkgs: name:
    let
      # Path into the LIVE working tree (relative to the repo root the app is
      # run from), NOT ${modpacksDir} — that resolves to the read-only flake
      # store snapshot. The app writes checksums.json back into the working
      # tree so it can be committed.
      script = pkgs.writeShellScriptBin "modpack-update-${name}" ''
        set -euo pipefail
        export PATH=${pkgs.rsync}/bin:${pkgs.coreutils}/bin:$PATH
        if [ ! -f flake.nix ]; then
          echo "modpack-update-${name}: run this from the repo root" >&2
          exit 1
        fi
        PACK="$PWD/modules/nixos/minecraft-server/modpacks/${name}"
        if [ ! -d "$PACK" ]; then
          echo "modpack-update-${name}: no modpack dir at $PACK" >&2
          exit 1
        fi
        DATA_DIR=''${1:-${if defaultDataDir != null then toString defaultDataDir else "$HOME/.local/share/PrismLauncher"}}
        SERVER=''${2:-}
        echo "modpack-update-${name}: regenerating checksums.json ..."
        (cd "$PACK" && ${pkgs.python3}/bin/python3 ${checksumsScript} mods > checksums.json)
        git add "$PACK/checksums.json"
        echo "modpack-update-${name}: building client content ..."
        OUT=$(${pkgs.nix}/bin/nix build ".#minecraft-modpack-${name}" --no-link --print-out-paths 2>/dev/null | tail -1)
        INST="$DATA_DIR/instances/${name}"
        echo "modpack-update-${name}: installing $OUT -> $INST"
        ${pkgs.python3}/bin/python3 ${instanceSyncScript} "$INST" "$OUT/meta.json" "$OUT/.minecraft" "$SERVER"
        echo "modpack-update-${name}: done — commit checksums.json"
      '';
    in
    {
      type = "app";
      program = "${script}/bin/modpack-update-${name}";
    };
in
{
  perSystem = { pkgs, ... }: {
    packages = {
      # packwiz CLI — run from a modpack dir: `nix run .#packwiz -- <cmd>`
      # Built from our nixpkgs (`pkgs.packwiz`), NOT from inputs.packwiz: the
      # upstream flake's `nix/vendor-hash` is empty, so its package fails to
      # build ("found empty hash, assuming sha256-AAA…"). nixpkgs' packwiz is
      # the same commit and maintained. The flake input is kept for upstream
      # parity / future fixes.
      inherit (pkgs) packwiz;
    } // lib.listToAttrs (map
      (name: lib.nameValuePair "minecraft-modpack-${name}" (mkClientInstance pkgs name))
      modpackNames);

    apps = lib.listToAttrs (concatMap
      (name: [
        (lib.nameValuePair "packwiz-checksums-${name}" (mkChecksumsApp pkgs name))
        (lib.nameValuePair "modpack-build-${name}" (mkBuildApp pkgs name))
        (lib.nameValuePair "modpack-update-${name}" (mkUpdateApp pkgs name))
      ])
      modpackNames);
  };
}
