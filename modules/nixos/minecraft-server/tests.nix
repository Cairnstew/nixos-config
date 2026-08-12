# Tests for my.services.minecraftServer.
{ config, lib, ... }:

let
  inherit (lib) mkIf mapAttrsToList;
  cfg = config.my.services.minecraftServer;
in
{
  config = mkIf cfg.enable {
    # ── L0: Nix assertions ────────────────────────────────────────────────────
    assertions = [
      {
        assertion = cfg.eula;
        message = ''
          my.services.minecraftServer.eula must be set to true — Mojang's EULA
          requires explicit acceptance before running any Minecraft server.
        '';
      }
      {
        assertion = cfg.servers != { };
        message = ''
          my.services.minecraftServer.enable = true but no servers are defined.
          Add at least one entry to my.services.minecraftServer.servers.
        '';
      }
    ];

    # ── L2: Smoke-test oneshot ───────────────────────────────────────────────
    systemd.services.minecraft-server-smoke-test = {
      description = "minecraft-server smoke test: verify configured server packages";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script =
        let
          checkServer = name: srv: ''
            echo "[smoke-test] ${name}: package = ${srv.package.pname or "?"} (${srv.package.name or "?"})"
            JAR=$(find ${srv.package} -name "*.jar" -not -path "*/libraries/*" | head -n1)
            if [ -n "$JAR" ]; then
              echo "[smoke-test] PASS: ${name} server jar found: $JAR"
            else
              echo "[smoke-test] FAIL: ${name} — no server jar found in ${srv.package}" >&2
              FAILED=1
            fi
            ${if srv.pack != null then ''
              echo "[smoke-test] ${name}: pack dir = ${srv.pack}"
              for d in mods config kubejs scripts datapacks defaultconfigs; do
                if [ -e "${srv.pack}/$d" ]; then
                  echo "[smoke-test] PASS: ${name} pack has $d/"
                else
                  echo "[smoke-test] note: ${name} pack has no $d/ (fine if unused)"
                fi
              done
            '' else ""}
          '';
        in
        ''
          set -uo pipefail
          FAILED=0

          ${lib.concatStrings (mapAttrsToList checkServer cfg.servers)}

          if [ "$FAILED" = "0" ]; then
            echo "[smoke-test] ALL CHECKS PASSED"
          else
            echo "[smoke-test] SOME CHECKS FAILED" >&2
            exit 1
          fi
        '';
    };
  };
}
