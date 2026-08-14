# Prism Launcher instances built from the repo's packwiz modpacks.
#
# Each enabled `my.programs.minecraft.instances.<name>` maps to the flake
# package `.#minecraft-modpack-<name>` (built from the pack's checksums.json —
# the same one the server uses) and gets:
#   - an instance dir under <dataDir>/instances/<name>/ with instance.cfg +
#     mmc-pack.json generated from the pack's meta.json (mmc-pack.json lives at
#     the instance root next to instance.cfg — Prism reads it via
#     instanceRoot()/mmc-pack.json, not inside .minecraft/),
#   - .minecraft/mods/*.jar synced from the built pack (pack owns mods/),
#   - .minecraft/config kubejs scripts datapacks defaultconfigs installed only
#     when absent, so player-edited files win (preserve semantics).
# Refreshed on home activation and on a timer, so client and server stay in
# sync with the same modpack definition.
#
# The instance.cfg + mmc-pack.json + mods/internal-dirs sync logic lives in
# modules/flake-parts/packwiz-instance-sync.py and is shared with the manual
# CLI apps `.#modpack-build-<name>` and `.#modpack-update-<name>`, so the
# declarative timer and the manual commands do exactly the same thing.
{ config, lib, pkgs, flake, ... }:

let
  cfg = config.my.programs.minecraft;
  inherit (lib) mkIf mkMerge optionalString concatStringsSep mapAttrsToList filterAttrs;
  system = pkgs.stdenv.hostPlatform.system;
  self = flake.inputs.self;

  dataDir =
    if cfg.dataDir != null then cfg.dataDir
    else if (flake.config.minecraft or { }).dataDir or null != null then flake.config.minecraft.dataDir
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
  # absent (player edits win). The Python logic lives in the shared
  # packwiz-instance-sync.py (modules/flake-parts/) so the manual CLI apps
  # (`.#modpack-build-<name>`, `.#modpack-update-<name>`) do exactly the same.
  syncScript = name: inst:
    let
      pkg = instancePkg name inst;
      syncPy = ../../flake-parts/packwiz-instance-sync.py;
    in
    pkgs.writeShellScript "minecraft-instance-${name}-sync" ''
      set -euo pipefail
      export PATH=${pkgs.rsync}/bin:${pkgs.coreutils}/bin:$PATH
      INST="${dataDir}/instances/${name}"
      SRC="${pkg}/.minecraft"
      META="${pkg}/meta.json"
      if [ ! -f "$META" ] || [ ! -d "$SRC" ]; then
        echo "minecraft-instance-${name}: ${pkg} has no built content — nothing to install" >&2
        exit 0
      fi
      mkdir -p "$INST/.minecraft"
      ${pkgs.python3}/bin/python3 ${syncPy} "$INST" "$META" "$SRC" "${inst.server}"
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

    systemd.user.services = mkMerge (mapAttrsToList
      (name: inst: {
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
      })
      enabled);

    systemd.user.timers = mkMerge (mapAttrsToList
      (name: inst: {
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
      })
      enabled);
  };
}
