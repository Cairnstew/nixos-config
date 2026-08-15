# Per-server web consoles: ttyd over the nix-minecraft systemd-socket FIFO.
{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkMerge optionalString;
  cfg = config.my.services.minecraftServer;

  # Servers that get a web console: enabled, module web on, per-server web on.
  webServers = lib.filterAttrs (_: srv: srv.enable && cfg.web.enable && srv.web.enable) cfg.servers;

  # Servers with an auto-restart pack watcher: enabled, packZip set, on.
  watchServers = lib.filterAttrs (_: srv: srv.enable && srv.packZip != null && srv.restartOnZipChange) cfg.servers;

  # Deterministic port allocation: base + sorted index (or per-server override).
  sorted = builtins.sort (a: b: a < b) (builtins.attrNames webServers);
  webPort = name:
    if webServers.${name}.web.port != null then webServers.${name}.web.port
    else cfg.web.portBase + (lib.length (builtins.filter (n: n < name) sorted));

  # FIFO path for a server, read from the live nix-minecraft config so socketPath
  # overrides are honored.
  fifoPath = name:
    let
      mgmt = config.services.minecraft-servers.servers.${name}.managementSystem;
    in
    mgmt."systemd-socket".stdinSocket.path name;

  # ── Console shim ────────────────────────────────────────────────────────────
  # Runs inside the ttyd pty. Backgrounds `tail -F` on the server log for
  # output; the read loop forwards every typed line to the console FIFO.
  # Dot-commands give start/stop/restart/status without needing a shell escape.
  mkShim = name: pkgs.writeShellScript "mc-web-${name}-shim" ''
    set -u
    NAME='${name}'
    SVC="minecraft-server-${name}"
    FIFO='${fifoPath name}'
    LOG='${cfg.dataDir}/${name}/logs/latest.log'
    SUDO="sudo -n"

    echo "== Minecraft console: $NAME =="
    echo "Type to send commands to the server console (e.g. /list)."
    echo "Dot-commands: .status .start .stop .restart .help"

    # Follow the log; -F retries until the file exists (fresh server).
    ${pkgs.coreutils}/bin/tail -F -n 100 "$LOG" 2>/dev/null &
    TAILPID=$!
    trap 'kill $TAILPID 2>/dev/null || true' EXIT

    while IFS= read -r line; do
      case "$line" in
        .status)  $SUDO /run/current-system/sw/bin/systemctl status "$SVC" --no-pager 2>&1 | head -40 ;;
        .start)   $SUDO /run/current-system/sw/bin/systemctl start "$SVC" 2>&1 ;;
        .stop)    $SUDO /run/current-system/sw/bin/systemctl stop "$SVC" 2>&1 ;;
        .restart) $SUDO /run/current-system/sw/bin/systemctl restart "$SVC" 2>&1 ;;
        .help)    echo "commands: .status .start .stop .restart ; anything else is sent to the server console" ;;
        *)
          if [ -p "$FIFO" ]; then
            printf '%s\n' "$line" > "$FIFO"
          else
            echo "[server not running — no console fifo yet; use .start]"
          fi
          ;;
      esac
    done
  '';

  # ── ttyd launcher (reads password file, execs ttyd) ─────────────────────────
  mkWebService = name:
    let
      shim = mkShim name;
      port = toString (webPort name);
      authArgs = optionalString (cfg.web.username != null && cfg.web.passwordFile != null) ''
        --credential "${cfg.web.username}:\"$PASSWORD\""
      '';
      launcher = pkgs.writeShellScript "mc-web-${name}-launcher" ''
        set -euo pipefail
        ${optionalString (cfg.web.passwordFile != null) ''
          PASSWORD=$(cat "${cfg.web.passwordFile}")
        ''}
        exec ${pkgs.ttyd}/bin/ttyd \
          --port ${port} \
          --interface ${cfg.web.bind} \
          --writable \
          --max-clients 2 \
          --check-origin \
          ${authArgs} \
          ${shim}
      '';
    in
    {
      "mc-web-${name}" = {
        description = "Minecraft web console: ${name}";
        after = [ "network.target" ];
        wants = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = launcher;
          User = cfg.web.user;
          Group = "minecraft";
          Restart = "on-failure";
          RestartSec = "2s";
        };
      };
    };

  # ── Dashboard management API ───────────────────────────────────────────────
  # Loopback HTTP service exposing per-server status (state, players, uptime)
  # and start/stop/restart actions for the proxy dashboard's Minecraft section
  # (my.services.proxy.dashboard.minecraft). Runs as the web console user,
  # which already holds NOPASSWD sudo for `systemctl {start,stop,restart,status}
  # minecraft-server-*`. Proxied by Caddy at /api/minecraft/.
  mkApiService =
    let
      apiScript = ./api.py;
      servers = builtins.attrNames (lib.filterAttrs (_: srv: srv.enable) cfg.servers);
    in
    {
      "minecraft-dashboard-api" = {
        description = "Minecraft dashboard management API";
        after = [ "network.target" ];
        wants = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        # sudo lives in /run/wrappers (NixOS setuid wrapper); systemctl is in
        # the systemd package. Provide both via PATH so the API's subprocess
        # calls (sudo systemctl ...) resolve like the web-console shim does.
        path = [ pkgs.sudo pkgs.systemd pkgs.coreutils ];
        serviceConfig = {
          ExecStart = "${pkgs.python3}/bin/python3 ${apiScript}";
          User = cfg.web.user;
          Group = "minecraft";
          Environment = [
            "MC_DATA_DIR=${cfg.dataDir}"
            "MC_SERVERS=${lib.concatStringsSep ":" servers}"
            "MC_API_PORT=${toString cfg.api.port}"
          ];
          Restart = "on-failure";
          RestartSec = "2s";
        };
      };
    };

  mkUpstream = name:
    let
      port = webPort name;
    in
    {
      "mc-${name}" = {
        inherit port;
        path = "/mc/${name}/";
        stripPrefix = true;
        displayName = "Minecraft console: ${name}";
      };
    };

  # ── Pack watcher: restart server when packZip changes ─────────────────────
  # A systemd.path unit watches the packZip file; on any change event it runs a
  # oneshot that only restarts the server if the zip's SHA-256 actually differs
  # from the last unpacked pack (the stamp file written by extraStartPre). scp
  # writes a temp file then renames it — the path unit may fire on both, but
  # the hash check makes the second trigger a no-op, so no double restarts.
  mkWatcherPath = name: srv:
    let
      zipPath =
        if lib.hasPrefix "/" srv.packZip then srv.packZip
        else "${cfg.packDir}/${srv.packZip}";
    in
    {
      "minecraft-server-${name}-pack-watcher" = {
        description = "Minecraft pack watcher for ${name}";
        wantedBy = [ "paths.target" ];
        pathConfig = {
          PathChanged = zipPath;
          Unit = "minecraft-server-${name}-pack-watcher.service";
        };
      };
    };

  mkWatcherService = name: srv:
    let
      zipPath =
        if lib.hasPrefix "/" srv.packZip then srv.packZip
        else "${cfg.packDir}/${srv.packZip}";
      stamp = "${cfg.dataDir}/${name}/.mc-pack.stamp";
      svc = "minecraft-server-${name}";
      script = pkgs.writeShellScript "mc-pack-watch-${name}" ''
        set -u
        ZIP='${zipPath}'
        STAMP='${stamp}'
        SVC='${svc}'
        [ -f "$ZIP" ] || exit 0
        NEW=$(${pkgs.coreutils}/bin/sha256sum "$ZIP" | ${pkgs.coreutils}/bin/cut -d' ' -f1)
        OLD=$(${pkgs.coreutils}/bin/cat "$STAMP" 2>/dev/null || true)
        if [ "$NEW" != "$OLD" ]; then
          echo "[mc-watch] ${name}: pack zip changed — restarting $SVC"
          ${pkgs.systemd}/bin/systemctl restart "$SVC"
        fi
      '';
    in
    {
      "minecraft-server-${name}-pack-watcher" = {
        description = "Minecraft pack watcher trigger for ${name}";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = script;
        };
      };
    };
in
{
  config = mkMerge [
    (mkIf cfg.enable {
      # ── Pack watcher (restart on zip change) — independent of the web console.
      systemd.services = mkMerge (builtins.map (name: (mkWatcherService name watchServers.${name})) (builtins.attrNames watchServers));

      systemd.paths = mkMerge (builtins.map (name: (mkWatcherPath name watchServers.${name})) (builtins.attrNames watchServers));
    })
    (mkIf (cfg.enable && cfg.web.enable) {
      # Dedicated least-privilege console user in the minecraft group (fifo write
      # access) with scoped systemctl rights for exactly the server units.
      users.users.${cfg.web.user} = {
        isSystemUser = true;
        group = "minecraft";
        # The NixOS sudo wrapper (/run/wrappers/bin/sudo) is setuid root:wheel
        # mode 4750 — only wheel members can exec it. The user needs it for the
        # web-console dot-commands and the dashboard management API; sudoers
        # (below) already scopes it to exactly `systemctl {start,stop,restart,
        # status} minecraft-server-*`, so wheel membership is safe.
        extraGroups = [ "wheel" ];
        shell = "/run/current-system/sw/bin/bash";
      };

      security.sudo.extraRules = [
        {
          users = [ cfg.web.user ];
          commands = builtins.map
            (cmd: {
              command = "/run/current-system/sw/bin/systemctl ${cmd} minecraft-server-*";
              options = [ "NOPASSWD" ];
            }) [ "start" "stop" "restart" "status" ];
        }
      ];

      networking.firewall.allowedTCPPorts =
        lib.mkIf cfg.web.openFirewall (builtins.map webPort (builtins.attrNames webServers));

      systemd.services = mkMerge (
        (builtins.map mkWebService (builtins.attrNames webServers))
        # Dashboard management API (status + start/stop/restart actions).
        ++ lib.optional cfg.api.enable mkApiService
      );

      my.services.proxy.upstreams = lib.mkIf cfg.web.proxyUpstream
        (lib.mkMerge (builtins.map mkUpstream (builtins.attrNames webServers)));

      # Dashboard management section: register the API with the proxy dashboard.
      my.services.proxy.dashboard.minecraft = lib.mkIf cfg.api.enable {
        enable = true;
        host = "127.0.0.1";
        port = cfg.api.port;
        apiPath = "/api/minecraft";
      };
    })
  ];
}
