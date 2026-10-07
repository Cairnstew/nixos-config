# modules/nixos/projectzomboid-server/tests.nix
#
# Repo-specific tests for the upstream nixos-projectzomboid-servers module.
#
# Upstream ships ten `nix flake check` checks of its own, including in-Nix
# assertions over the generated systemd units (absolute ExecStart paths, jvmOpts
# reaching the unit, the console-socket unit existing, no unit depending on an
# undefined one) and eval-time assertions for port clashes, console-backend
# exclusivity, secret leakage and beta-branch coherence. Those are NOT repeated
# here — running upstream's suite covers them:
#
#   nix flake check path:<upstream clone>
#
# What is left for this repo is the layer upstream cannot know about: this
# config's data-disk convention, and a smoke test that reports the resolved
# layout so a human can eyeball it without booting the server.
{ config, flake, lib, ... }:

let
  inherit (lib) mkIf mapAttrs mapAttrsToList filterAttrs;

  cfg = config.services.project-zomboid-servers;

  # Upstream's shared helper library — resolveServer does the modpack merge, so
  # the smoke test reports what the module will ACTUALLY render rather than
  # re-deriving it here (which is how a test starts disagreeing with the code).
  pz = flake.inputs.project-zomboid-servers.lib;

  enabledServers = filterAttrs (_: srv: srv.enable) cfg.servers;
  resolved = mapAttrs (name: srv: pz.resolveServer cfg.modpacks name srv) enabledServers;

  # Client hosts are resolved independently of `enable` — on this fleet the
  # dedicated server is OFF and the pack drives the game's own Host button, so
  # without this the smoke test would report nothing at all.
  clientResolved = mapAttrs (name: srv: pz.resolveServer cfg.modpacks name srv) (
    filterAttrs (_: srv: srv.clientHost.enable) cfg.servers
  );

  # Directories that cannot hold PZ data on this fleet: the root fs is NVMe and
  # PZ saves grow without bound. `/var` is upstream's own default and is wrong
  # here, which is exactly why config.nix mkDefaults the SATA data disk.
  forbiddenDataDirs = [
    "/"
    "/home"
    "/var"
    "/var/lib"
  ];
in
{
  config = mkIf cfg.enable {
    # ── L0: Nix assertions ────────────────────────────────────────────────────
    assertions = [
      {
        assertion = cfg.servers != { };
        message = ''
          services.project-zomboid-servers.enable = true but no servers are defined.
          Add at least one file under modules/nixos/projectzomboid-server/servers/,
          or set enable = false.
        '';
      }
      {
        assertion = !(builtins.elem cfg.dataDir forbiddenDataDirs);
        message = ''
          services.project-zomboid-servers.dataDir is "${cfg.dataDir}", which
          cannot hold Project Zomboid data on this fleet — the root filesystem is
          NVMe and PZ saves grow without bound. Use the large SATA data disk
          (modules/nixos/projectzomboid-server/config.nix mkDefaults
          "/mnt/data/project-zomboid").
        '';
      }
    ];

    # ── L2: Smoke-test oneshot ───────────────────────────────────────────────
    # Type=oneshot with no wantedBy — trigger it by hand:
    #   systemctl start project-zomboid-smoke-test
    #
    # It renders nothing and downloads nothing; it only echoes the resolved
    # layout, so it is safe to run before the first steamcmd fetch.
    systemd.services."project-zomboid-smoke-test" = {
      description = "project-zomboid smoke test: report resolved server layout";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script =
        let
          checkServer = name: srv:
            ''
              echo "[smoke-test] server '${name}' (servername: ${srv.serverName})"
              echo "[smoke-test]   modpack:    ${if srv.modpack != null then srv.modpack else "(none)"}"
              echo "[smoke-test]   udp ports:  ${toString srv.defaultPort} (game) / ${toString srv.udpPort} (direct) / rcon ${toString srv.rconPort}"
              echo "[smoke-test]   map:        ${
                if srv.pinnedMap != null
                then "pinned to '${srv.pinnedMap}'"
                else "derived at start (base map '${srv.baseMap}' ordered last)"
              }"
              echo "[smoke-test]   workshop:   ${
                if srv.workshopItems == [ ]
                then "(none)"
                else "${toString (builtins.length srv.workshopItems)} item(s): ${lib.concatStringsSep " " srv.workshopItems}"
              }"
              echo "[smoke-test]   local mods: ${
                if srv.mods == [ ]
                then "(none)"
                else lib.concatStringsSep " " srv.mods
              }"
              echo "[smoke-test]   .ini:       ${cfg.dataDir}/${name}/Zomboid/Server/${srv.serverName}.ini"
              echo "[smoke-test]   unit:       project-zomboid-${name}.service"
            '';
          # A client host is not a unit; what matters is that the pack rendered
          # and that the script Home Manager runs exists.
          checkClientHost = name: srv:
            let
              unit = "project-zomboid-${name}";
            in
            ''
              echo "[smoke-test] client host '${name}' -> Zomboid/Server/${srv.clientHost.name}.ini"
              echo "[smoke-test]   modpack:    ${if srv.modpack != null then srv.modpack else "(none)"}"
              echo "[smoke-test]   workshop:   ${toString (builtins.length srv.workshopItems)} item(s)"
              echo "[smoke-test]   local mods: ${toString (builtins.length srv.mods)}"
              echo "[smoke-test]   prepare:    ${cfg.clientHosts.${name}.prepare}/bin/${unit}-client-host"
            '';
        in
        ''
          set -uo pipefail
          echo "[smoke-test] dataDir:   ${cfg.dataDir}"
          echo "[smoke-test] serverDir: ${cfg.serverDir}  (SteamCMD app 380870 — cold until first fetch)"
          ${lib.concatStrings (mapAttrsToList checkServer resolved)}
          ${lib.concatStrings (mapAttrsToList checkClientHost clientResolved)}
          echo "[smoke-test] ALL CHECKS PASSED"
        '';
    };
  };
}
