# Wires my.services.projectZomboid into a working set of data dirs, users, and
# (via services.nix) per-server systemd units. This file handles the non-unit
# plumbing: user/group, prepare-dirs, firewall, opencode wiring, and the shared
# steamcmd server install.
{ config, lib, flake, pkgs, ... }:

let
  inherit (lib) mkIf mkMerge mkDefault;
  cfg = config.my.services.projectZomboid;
  me = flake.config.me;
  pz = import ./lib.nix { inherit lib; };

  # Enabled servers, resolved (module-merged) with the helper.
  enabledServers = lib.filterAttrs (_: srv: srv.enable) cfg.servers;
  resolved = lib.mapAttrs (name: srv: pz.resolveServer cfg.modpacks name srv) enabledServers;

  serverDir = "${cfg.dataDir}/server";  # shared app-380870 install
  controlFifo = name: "${cfg.dataDir}/${name}/control.fifo";

  # ── steamcmd update of the shared install (app 380870) ─────────────────────
  mkUpdateScript = pkgs.writeShellScript "pz-update-server" ''
    set -euo pipefail
    export HOME="${cfg.dataDir}"
    ${lib.getExe cfg.steamcmd} \
      +force_install_dir ${serverDir} \
      +login anonymous \
      +app_update 380870 validate \
      +quit
    # Download the Workshop items referenced by enabled servers into the shared
    # install so PZ finds them (PZ looks in the install's steamapps/workshop).
    ${lib.concatStringsSep "\n" (builtins.map (name: ''
      ${lib.concatStringsSep "\n" (map (id: ''
        ${lib.getExe cfg.steamcmd} \
          +force_install_dir ${serverDir} \
          +login anonymous \
          +workshop_download_item 108600 ${id} \
          +quit
      '') resolved.${name}.workshopItems)}
    '') (builtins.attrNames resolved))}
  '';
in
{
  config = mkMerge [
    (mkIf cfg.enable {
      # ── User / group ───────────────────────────────────────────────────────
      users.users.${cfg.user} = {
        isSystemUser = true;
        inherit (cfg) group;
        home = cfg.dataDir;
        createHome = true;
        description = "Project Zomboid dedicated server user";
      };
      users.groups.${cfg.group} = { };

      # Primary user in the group so they can reach the data dir / control fifos.
      users.groups.${cfg.group}.members = [ me.username ];

      # ── Firewall: open each enabled server's two UDP ports ────────────────
      networking.firewall.allowedUDPPorts = lib.concatMap
        (s: lib.optionals s.openFirewall [ s.defaultPort s.udpPort ])
        (lib.attrValues resolved);
    })

    # ── OpenCode integration — available wherever opencode is enabled ────────
    (mkIf cfg.opencode.enable {
      my.homeManager.extraConfig.my.programs.opencode = {
        tools = {
          pz-modpack-status = ./opencode/tools/pz-modpack-status.ts;
        };
        skills.pz-modpack = builtins.readFile ./opencode/skill.md;
      };
    })
  ];
}
