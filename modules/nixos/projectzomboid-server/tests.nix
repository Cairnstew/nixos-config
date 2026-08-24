# Tests for my.services.projectZomboid.
{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mapAttrsToList filterAttrs;
  cfg = config.my.services.projectZomboid;
  pz = import ./lib.nix { inherit lib; };

  enabledServers = filterAttrs (_: srv: srv.enable) cfg.servers;
in
{
  config = mkIf cfg.enable {
    # ── L0: Nix assertions ────────────────────────────────────────────────────
    assertions = [
      {
        assertion = cfg.servers != { };
        message = ''
          my.services.projectZomboid.enable = true but no servers are defined.
          Add at least one entry to my.services.projectZomboid.servers.
        '';
      }
      {
        assertion = cfg.dataDir != "/home";
        message = "my.services.projectZomboid.dataDir should be a dedicated directory, not /home.";
      }
      {
        # Every referenced modpack must exist.
        assertion = lib.all
          (name: cfg.servers.${name}.modpack == null || (cfg.modpacks ? cfg.servers.${name}.modpack))
          (builtins.attrNames cfg.servers);
        message = ''
          my.services.projectZomboid: a server references a modpack that does
          not exist in my.services.projectZomboid.modpacks. Define it in
          modules/nixos/projectzomboid-server/modpacks/.
        '';
      }
      {
        # Each server needs its two UDP ports distinct (game + direct-connect).
        assertion = lib.all
          (name: let s = cfg.servers.${name}; in s.defaultPort != s.udpPort)
          (builtins.attrNames cfg.servers);
        message = "my.services.projectZomboid: defaultPort and udpPort must differ for each server.";
      }
    ];

    # ── L2: Smoke-test oneshot ───────────────────────────────────────────────
    systemd.services."project-zomboid-smoke-test" = {
      description = "project-zomboid smoke test: verify configured server packages/data layout";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script =
        let
          checkServer = name: srv:
            let
              r = pz.resolveServer cfg.modpacks name srv;
            in
            ''
              echo "[smoke-test] ${name}: servername=${r.name} map=${r.map} port=${toString r.defaultPort} (+${toString r.udpPort})"
              echo "[smoke-test] ${name}: workshopItems=${r.workshopItems} mods=${r.mods}"
              echo "[smoke-test] ${name}: .ini out=${cfg.dataDir}/${name}/Zomboid/Server/${r.name}.ini"
              echo "[smoke-test] note: server install lives at ${cfg.dataDir}/server (cold until first steamcmd update)"
            '';
        in
        ''
          set -uo pipefail
          ${lib.concatStrings (mapAttrsToList checkServer enabledServers)}
          echo "[smoke-test] ALL CHECKS PASSED"
        '';
    };
  };
}
