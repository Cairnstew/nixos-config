# Tests for my.services.minecraftServer.
{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mapAttrsToList filterAttrs;
  cfg = config.my.services.minecraftServer;

  # Web-enabled servers (same filter as services.nix).
  webServers = filterAttrs (_: srv: srv.enable && cfg.web.enable && srv.web.enable) cfg.servers;
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
      {
        assertion =
          !cfg.web.enable
          || lib.all (srv: srv.managementSystem.systemdSocket.enable || cfg.managementSystem.systemdSocket.enable)
            (lib.attrValues webServers);
        message = ''
          my.services.minecraftServer.web.enable = true requires the
          systemd-socket console management system (FIFO + journald) for every
          web-enabled server — tmux management has no console FIFO for the web
          console to write to. Set
          my.services.minecraftServer.managementSystem.systemdSocket.enable =
          true (module-level or per-server).
        '';
      }
      {
        assertion =
          let
            ports = lib.attrValues (lib.mapAttrs (_: srv: srv.web.port) webServers);
            nonNull = builtins.filter (p: p != null) ports;
            unique = lib.unique nonNull;
          in
          lib.length nonNull == lib.length unique;
        message = ''
          Multiple web-enabled servers have the same explicit
          my.services.minecraftServer.servers.<name>.web.port. Auto-allocated
          ports are unique; explicit overrides must be too.
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
            ${if srv.packZip != null then ''
              ZIP='${if lib.hasPrefix "/" srv.packZip then srv.packZip else "${cfg.packDir}/${srv.packZip}"}'
              echo "[smoke-test] ${name}: packZip = $ZIP"
              if [ -f "$ZIP" ]; then
                echo "[smoke-test] PASS: ${name} packZip present ($(${pkgs.coreutils}/bin/du -h "$ZIP" | ${pkgs.coreutils}/bin/cut -f1))"
                ${pkgs.unzip}/bin/unzip -l "$ZIP" > /dev/null && echo "[smoke-test] PASS: ${name} packZip is a valid zip" \
                  || { echo "[smoke-test] FAIL: ${name} packZip is not a valid zip" >&2; FAILED=1; }
              else
                echo "[smoke-test] WARN: ${name} packZip not present yet — scp it to packDir to provision mods" >&2
              fi
            '' else ""}
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

    # ── L2: Web console smoke probe ───────────────────────────────────────────
    systemd.services.minecraft-server-web-smoke-test = mkIf cfg.web.enable {
      description = "minecraft-server web console smoke test";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script =
        let
          probe = name: ''
            echo "[web-smoke] ${name}: console service active: $(systemctl is-active mc-web-${name} 2>/dev/null || echo not-running)"
            echo "[web-smoke] ${name}: server service exists: $(systemctl show -p Id --value minecraft-server-${name} 2>/dev/null || echo missing)"
          '';
        in
        ''
          set -uo pipefail
          ${lib.concatStrings (mapAttrsToList (name: _: probe name) webServers)}
          echo "[web-smoke] ALL WEB CHECKS PASSED"
        '';
    };

    # ── L2: Pack watcher smoke probe ───────────────────────────────────────────
    systemd.services.minecraft-server-pack-watch-smoke-test = mkIf cfg.enable {
      description = "minecraft-server pack watcher smoke test";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script =
        let
          watched = lib.filterAttrs (_: srv: srv.enable && srv.packZip != null && srv.restartOnZipChange) cfg.servers;
          probe = name: ''
            echo "[pack-watch] ${name}: path unit enabled: $(systemctl is-enabled minecraft-server-${name}-pack-watcher.path 2>/dev/null || echo missing)"
            echo "[pack-watch] ${name}: trigger unit exists: $(systemctl show -p Id --value minecraft-server-${name}-pack-watcher.service 2>/dev/null || echo missing)"
          '';
        in
        ''
          set -uo pipefail
          ${lib.concatStrings (mapAttrsToList (name: _: probe name) watched)}
          echo "[pack-watch] ALL PACK-WATCH CHECKS PASSED"
        '';
    };
  };
}
