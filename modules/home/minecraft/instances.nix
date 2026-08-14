# Prism Launcher instances built from the repo's packwiz modpacks.
#
# Each enabled `my.programs.minecraft.instances.<name>` maps to the flake
# package `.#minecraft-modpack-<name>` (built from the pack's checksums.json —
# the same one the server uses) and gets:
#   - an instance dir under <dataDir>/instances/<name>/ with instance.cfg +
#     .minecraft/mmc-pack.json generated from the pack's meta.json,
#   - .minecraft/mods/*.jar synced from the built pack (pack owns mods/),
#   - .minecraft/config kubejs scripts datapacks defaultconfigs installed only
#     when absent, so player-edited files win (preserve semantics).
# Refreshed on home activation and on a timer, so client and server stay in
# sync with the same modpack definition.
{ config, lib, pkgs, flake, ... }:

let
  cfg = config.my.programs.minecraft;
  inherit (lib) mkIf mkMerge optionalString concatStringsSep mapAttrsToList filterAttrs;
  system = pkgs.stdenv.hostPlatform.system;
  self = flake.inputs.self;

  dataDir =
    if cfg.dataDir != null then cfg.dataDir
    else "${config.home.homeDirectory}/.local/share/PrismLauncher";

  # Resolve the built client content for an instance: explicit package, else
  # the flake's minecraft-modpack-<name> package.
  instancePkg = name: inst:
    if inst.package != null then inst.package
    else
      self.packages.${system}."minecraft-modpack-${name}" or (builtins.throw ''
        my.programs.minecraft.instances.${name}: no modpack '${name}' under
        modules/nixos/minecraft-server/modpacks/ and no explicit `package`
        set. Add the modpack (it must have a checksums.json) or set
        instances.${name}.package.
      '');

  # One-shot script: write instance.cfg + mmc-pack.json from meta.json, then
  # sync mods (pack-owned, with --delete) and seed pack internal dirs only when
  # absent (player edits win).
  syncScript = name: inst:
    let
      pkg = instancePkg name inst;
    in
    pkgs.writeShellScript "minecraft-instance-${name}-sync" ''
      set -euo pipefail
      INST="${dataDir}/instances/${name}"
      SRC="${pkg}/.minecraft"
      META="${pkg}/meta.json"
      if [ ! -f "$META" ] || [ ! -d "$SRC" ]; then
        echo "minecraft-instance-${name}: ${pkg} has no built content — nothing to install" >&2
        exit 0
      fi
      mkdir -p "$INST/.minecraft"

      # instance.cfg + mmc-pack.json from the pack's meta.json.
      ${pkgs.python3}/bin/python3 - "$INST" "$META" "${inst.server}" <<'PY'
      import json, os, sys
      inst, meta_path, server = sys.argv[1], sys.argv[2], sys.argv[3]
      meta = json.load(open(meta_path))
      os.makedirs(inst + "/.minecraft", exist_ok=True)

      lines = ["InstanceType=OneSix", "name=" + (meta.get("packName") or meta["name"]), "[Java]"]
      if server:
          lines += ["[JoinServerOnLaunch]", "address=" + server]
      lines += [
          "[OneSix]",
          "MinecraftVersion=" + meta["mc"],
          "Components=" + meta["loaderUid"] + ":" + meta["loaderVersion"],
      ]
      with open(inst + "/instance.cfg", "w") as f:
          f.write("\n".join(lines) + "\n")

      mmc = {
          "components": [
              {"uid": "net.minecraft", "version": meta["mc"]},
              {"uid": meta["loaderUid"], "version": meta["loaderVersion"], "important": True},
          ],
          "formatVersion": 1,
      }
      with open(inst + "/.minecraft/mmc-pack.json", "w") as f:
          json.dump(mmc, f, indent=2)
      PY

      # Mods: pack owns the mods dir — refresh wholesale (dereference the
      # store symlinks so the instance is self-contained). Store paths are
      # read-only, so chmod before --delete or rsync can't clear stale jars.
      if [ -d "$SRC/mods" ]; then
        ${pkgs.rsync}/bin/rsync -a -L --chmod=F644 "$SRC/mods/" "$INST/.minecraft/mods/"
        ${pkgs.coreutils}/bin/chmod -R u+w "$INST/.minecraft/mods"
        ${pkgs.rsync}/bin/rsync -a --delete -L "$SRC/mods/" "$INST/.minecraft/mods/"
        ${pkgs.coreutils}/bin/chmod -R a-w,u+w "$INST/.minecraft/mods"
      fi

      # Pack internal content: seed defaults only when absent (player edits win).
      for d in config kubejs scripts datapacks defaultconfigs; do
        if [ -d "$SRC/$d" ]; then
          mkdir -p "$INST/.minecraft/$d"
          ${pkgs.rsync}/bin/rsync -a -L --ignore-existing "$SRC/$d/" "$INST/.minecraft/$d/"
        fi
      done

      echo "minecraft-instance-${name}: installed ${pkg} -> $INST"
    '';

  enabled = filterAttrs (_: inst: inst.enable) cfg.instances;
in
{
  config = mkIf (cfg.enable && enabled != { }) {
    home.activation."minecraft-instances" = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      concatStringsSep "\n" (mapAttrsToList
        (name: inst: optionalString inst.refreshOnActivation ''
          ${syncScript name inst}
        '')
        enabled)
    );

    systemd.user.services = mkMerge (mapAttrsToList (name: inst: {
      "minecraft-instance-${name}" = {
        Unit = {
          Description = "Prism Launcher instance ${name} (from packwiz modpack)";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${syncScript name inst}";
        };
      };
    }) enabled);

    systemd.user.timers = mkMerge (mapAttrsToList (name: inst: {
      "minecraft-instance-${name}" = {
        Unit = {
          Description = "Prism Launcher instance ${name} refresh timer";
        };
        Timer = {
          OnBootSec = inst.onBootDelaySec;
          OnUnitActiveSec = inst.syncInterval;
          OnActiveSec = inst.syncInterval;
          Persistent = true;
        };
        Install = {
          WantedBy = [ "timers.target" ];
        };
      };
    }) enabled);
  };
}
