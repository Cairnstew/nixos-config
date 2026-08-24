# Per-server Project Zomboid systemd units, the shared steamcmd update
# service/timer, and optional ttyd web consoles (over the console FIFO).
{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkMerge optionalString;
  cfg = config.my.services.projectZomboid;
  pz = import ./lib.nix { inherit lib; };

  enabledServers = lib.filterAttrs (_: srv: srv.enable) cfg.servers;
  resolved = lib.mapAttrs (name: srv: pz.resolveServer cfg.modpacks name srv) enabledServers;

  serverDir = "${cfg.dataDir}/server";  # shared app-380870 install
  fifoPath = name: "${cfg.dataDir}/${name}/control.fifo";
  mergeIni = ./scripts/merge_ini.py;

  # Servers that get a web console.
  webServers = lib.filterAttrs (_: srv: cfg.web.enable && srv.opencodeWeb) resolved;
  sorted = builtins.sort (a: b: a < b) (builtins.attrNames webServers);
  webPort = name:
    cfg.web.portBase + (lib.length (builtins.filter (n: n < name) sorted));

  # ── Start-prep: every server gets its Zomboid/Server/<name>.ini (merged in
  # place so PZ's runtime keys Survive) + a fresh <name>_SandboxVars.lua, plus a
  # console FIFO and Workshop mod symlinks.
  mkStartPre = name: srv:
    let
      ini = "${cfg.dataDir}/${name}/Zomboid/Server/${srv.name}.ini";
      sandbox = "${cfg.dataDir}/${name}/Zomboid/Server/${srv.name}_SandboxVars.lua";
      workshopSrc = id: "${serverDir}/steamapps/workshop/content/108600/${id}";
    in
    ''
      export HOME="${cfg.dataDir}/${name}"
      mkdir -p "${cfg.dataDir}/${name}/Zomboid/Server" \
               "${cfg.dataDir}/${name}/Zomboid/Workshop/content/108600"

      # Merged .ini (preserves PZ runtime keys)
      ${pkgs.python3}/bin/python3 ${mergeIni} "${ini}" \
        DefaultPort=${toString srv.defaultPort} \
        UDPPort=${toString srv.udpPort} \
        RCONPort=${toString srv.rconPort} \
        Public=${if srv.settings.public then "true" else "false"} \
        PublicName=${srv.settings.publicName} \
        MaxPlayers=${toString srv.settings.maxPlayers} \
        Open=${if srv.settings.open then "true" else "false"} \
        Map=${srv.map} \
        Mods=${lib.concatStringsSep "," srv.mods} \
        WorkshopItems=${lib.concatStringsSep ";" srv.workshopItems} \
        Whitelist=${lib.concatStringsSep "," srv.whitelist} \
        Users=${lib.concatStringsSep "," srv.admins} \
        ${lib.optionalString (srv.passwordFile != null) "Password=$(cat ${srv.passwordFile})"}
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: ''
        ${pkgs.python3}/bin/python3 ${mergeIni} "${ini}" "${k}=${toString v}"
      '') (lib.removeAttrs srv.settings ["public" "publicName" "maxPlayers" "open" "map"]))}

      # Fresh SandboxVars lua (sandbox is fully declarative)
      cat > "${sandbox}" <<'SANDBOX'
      ${pz.renderSandbox { settings = srv.sandbox; }}
      SANDBOX

      # Console FIFO for systemctl-fed commands (recreated idempotently)
      [ -p "${fifoPath name}" ] || mkfifo -m 0660 "${fifoPath name}"
      chown ${cfg.user}:${cfg.group} "${fifoPath name}" || true

      # Link Workshop mods from the shared install into this server's home so PZ
      # sees them under Zomboid/Workshop/content/108600/<id>.
      ${lib.concatStringsSep "\n" (map (id: ''
        if [ -d "${workshopSrc id}" ]; then
          ln -sfn "${workshopSrc id}" "${cfg.dataDir}/${name}/Zomboid/Workshop/content/108600/${id}"
        fi
      '') srv.workshopItems)}
    '';

  # ── The launcher: run the server under steam-run, wired to the FIFO stdin so
  # systemd (ExecStop) can send "save" / "quit" for a clean shutdown.
  mkLauncher = name: srv:
    let
      script = pkgs.writeShellScript "pz-launch-${name}" ''
        set -e
        cd "${serverDir}"
        exec ${lib.getExe cfg.steamRun} ./start-server.sh -servername "${srv.name}" < "${fifoPath name}"
      '';
    in
    script;

  # ExecStop: send a graceful save-then-quit to the FIFO.
  mkStopScript = name: srv:
    let
      script = pkgs.writeShellScript "pz-stop-${name}" ''
        FIFO="${fifoPath name}"
        if [ -p "$FIFO" ]; then
          echo "save" > "$FIFO"
          sleep 15
          echo "quit" > "$FIFO"
        fi
      '';
    in
    script;

  mkServerUnit = name: srv:
    lib.nameValuePair "projectzomboid-${name}" {
      description = srv.description;
      wantedBy = lib.optionals srv.autoStart [ "multi-user.target" ];
      after = [ "network-online.target" "project-zomboid-prepare-dirs.service" ];
      wants = [ "network-online.target" ];
      requires = [ "project-zomboid-prepare-dirs.service" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = serverDir;
        Environment = "HOME=${cfg.dataDir}/${name}";

        ExecStartPre = mkStartPre name srv;
        # Write a stub server-config so the process doesn't stall on a missing
        # admin-password prompt: if there's no .ini yet (first boot), the module
        # couldn't seed a password, so generate one from /proc entropy.
        ExecStart = builtins.toString (mkLauncher name srv);
        ExecStop = builtins.toString (mkStopScript name srv);
        # PZ's recommended systemd shutdown signal handling for a clean save.
        KillSignal = "SIGCONT";
        TimeoutStopSec = "60s";
        Restart = srv.restart;
        RestartSec = "5s";

        # Light hardening — MUST stay steam-run/bwrap compatible.
        PrivateTmp = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ "${cfg.dataDir}" ];
        ProtectHome = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        UMask = "0027";
      } // (lib.filterAttrs (_: v: v != null) {
        MemoryMax = srv.hardware.memoryMax;
        MemoryHigh = srv.hardware.memoryHigh;
        MemorySwapMax = srv.hardware.memorySwapMax;
        CPUQuota = srv.hardware.cpuQuota;
        Nice = if srv.hardware.nice != null then toString srv.hardware.nice else null;
        IOWeight = if srv.hardware.ioWeight != null then toString srv.hardware.ioWeight else null;
      }) // srv.extraServiceConfig;
    };

  # ── Web console (ttyd over the FIFO) ───────────────────────────────────────
  mkWebShim = name: srv:
    let
      log = "${cfg.dataDir}/${name}/Zomboid/Logs/server.txt";
    in
    pkgs.writeShellScript "pz-web-${name}-shim" ''
      set -u
      NAME='${name}'
      SVC="projectzomboid-${name}"
      FIFO='${fifoPath name}'
      LOG='${log}'
      SUDO="sudo -n"
      echo "== Project Zomboid console: $NAME =="
      echo "Type to send server commands. Dot-commands: .status .start .stop .restart .help"
      ${pkgs.coreutils}/bin/tail -F -n 100 "$LOG" 2>/dev/null &
      TAILPID=$!
      trap 'kill $TAILPID 2>/dev/null || true' EXIT
      while IFS= read -r line; do
        case "$line" in
          .status)  $SUDO /run/current-system/sw/bin/systemctl status "$SVC" --no-pager 2>&1 | head -40 ;;
          .start)   $SUDO /run/current-system/sw/bin/systemctl start "$SVC" 2>&1 ;;
          .stop)    $SUDO /run/current-system/sw/bin/systemctl stop "$SVC" 2>&1 ;;
          .restart) $SUDO /run/current-system/sw/bin/systemctl restart "$SVC" 2>&1 ;;
          .help)    echo "commands: .status .start .stop .restart ; anything else goes to the server console" ;;
          *)        if [ -p "$FIFO" ]; then printf '%s\n' "$line" > "$FIFO"; else echo "[not running]"; fi ;;
        esac
      done
    '';

  mkWebService = name: srv:
    let
      port = toString (webPort name);
      shim = mkWebShim name srv;
      authArgs = optionalString (cfg.web.username != null && cfg.web.passwordFile != null) ''
        --credential "${cfg.web.username}:\"$PASSWORD\""
      '';
      launcher = pkgs.writeShellScript "pz-web-${name}-launcher" ''
        set -euo pipefail
        ${optionalString (cfg.web.passwordFile != null) ''
          PASSWORD=$(cat "${cfg.web.passwordFile}")
        ''}
        exec ${pkgs.ttyd}/bin/ttyd \
          --port ${port} --interface ${cfg.web.bind} --writable --max-clients 2 --check-origin \
          ${authArgs} ${shim}
      '';
    in
    lib.nameValuePair "pz-web-${name}" {
      description = "Project Zomboid web console: ${name}";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.sudo pkgs.systemd pkgs.coreutils ];
      serviceConfig = {
        ExecStart = launcher;
        User = cfg.web.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = "2s";
      };
    };

  mkUpstream = name:
    lib.nameValuePair "pz-${name}" {
      port = webPort name;
      path = "/pz/${name}/";
      stripPrefix = true;
      displayName = "Project Zomboid console: ${name}";
    };

  # ── Shared steamcmd update service + optional timer ────────────────────────
  updateScript = pkgs.writeShellScript "pz-update" ''
    set -euo pipefail
    export HOME="${cfg.dataDir}"
    ${lib.getExe cfg.steamcmd} \
      +force_install_dir ${serverDir} +login anonymous +app_update 380870 validate +quit
    ${lib.concatStringsSep "\n" (builtins.map (name: ''
      ${lib.concatStringsSep "\n" (map (id: ''
        ${lib.getExe cfg.steamcmd} \
          +force_install_dir ${serverDir} +login anonymous +workshop_download_item 108600 ${id} +quit
      '') resolved.${name}.workshopItems)}
    '') (builtins.attrNames resolved))}
    # Restart all enabled servers so they pick up the new binaries/mods.
    ${lib.concatStringsSep "\n" (builtins.map (name: ''
      ${pkgs.systemd}/bin/systemctl try-restart projectzomboid-${name}.service
    '') (builtins.attrNames resolved))}
  '';
in
{
  config = mkIf cfg.enable {
    systemd.services = lib.mkMerge [
      # ── Shared install / update ────────────────────────────────────────────
      {
        "project-zomboid-update" = {
          description = "Project Zomboid server update (steamcmd app 380870 + Workshop mods)";
          serviceConfig = {
            Type = "oneshot";
            User = cfg.user;
            Group = cfg.group;
            WorkingDirectory = serverDir;
            ExecStart = updateScript;
          };
        };
      }
      # ── Per-server units ───────────────────────────────────────────────────
      (lib.mapAttrs' mkServerUnit resolved)
      # ── Web consoles ───────────────────────────────────────────────────────
      (lib.mkIf cfg.web.enable (lib.mkMerge (builtins.map
        (name: mkWebService name webServers.${name})
        (builtins.attrNames webServers))))
    ];

    systemd.timers."project-zomboid-update" = lib.mkIf (cfg.updateSchedule != null) {
      description = "Timer for Project Zomboid server updates";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.updateSchedule;
        Persistent = true;
      };
    };

    # ── Web console user + scoped sudo + firewall ───────────────────────────
    users.users.${cfg.web.user} = lib.mkIf cfg.web.enable {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ "wheel" ];
      shell = "/run/current-system/sw/bin/bash";
    };
    security.sudo.extraRules = lib.mkIf cfg.web.enable [
      {
        users = [ cfg.web.user ];
        commands = builtins.map
          (cmd: {
            command = "/run/current-system/sw/bin/systemctl ${cmd} projectzomboid-*";
            options = [ "NOPASSWD" ];
          }) [ "start" "stop" "restart" "status" ];
      }
    ];
    networking.firewall.allowedTCPPorts =
      lib.mkIf cfg.web.openFirewall (builtins.map (name: webPort name) (builtins.attrNames webServers));
    my.services.proxy.upstreams = lib.mkIf cfg.web.proxyUpstream
      (lib.mkMerge (builtins.map mkUpstream (builtins.attrNames webServers)));
  };
}
