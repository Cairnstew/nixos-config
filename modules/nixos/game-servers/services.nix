{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.game-servers;
  enabledServers = lib.filterAttrs (_: s: s.enable) cfg.servers;

  stateDirOf = name: server:
    if server.stateDir != null then server.stateDir else "${cfg.dataDir}/${name}";

  displayName = name: server:
    if server.name != "" then server.name else name;

  # Build the steamcmd install/update command as a self-contained script so
  # password files and quoting are handled safely.
  mkUpdateScript = name: server:
    let
      stateDir = stateDirOf name server;
      loginPassword =
        if server.login.passwordFile != null then
          "\"$(cat ${lib.escapeShellArg server.login.passwordFile})\""
        else
          "";
      branchArg = lib.optionalString (server.branch != null) "+beta ${server.branch}";
      validateArg = lib.optionalString server.validate "validate";
    in
    pkgs.writeShellScript "game-server-${name}-update" ''
      set -euo pipefail
      export HOME="${stateDir}"
      exec ${lib.getExe cfg.steamcmd} \
        +force_install_dir "${stateDir}" \
        +login ${lib.escapeShellArg server.login.user} ${loginPassword} \
        ${branchArg} \
        +app_update ${lib.escapeShellArg server.appId} ${validateArg} \
        +quit
    '';

  # Main server unit for a single game
  mkServerUnit = name: server:
    let
      stateDir = stateDirOf name server;
    in
    lib.nameValuePair "game-server-${name}" {
      description = "${displayName name server} dedicated server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ] ++ server.after;
      wants = [ "network-online.target" ] ++ server.wants;

      environment = { HOME = stateDir; } // server.environment;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = stateDir;

        ExecStartPre = lib.optional server.autoUpdate (mkUpdateScript name server)
          ++ server.extraExecStartPre;
        ExecStart = "${lib.getExe cfg.steamRun} ${
            lib.escapeShellArgs ([ "./${server.startCommand}" ] ++ server.args)
          }";
        Restart = server.restart;
        RestartSec = server.restartSec;
        TimeoutStartSec = server.timeoutStartSec;
        Nice = server.nice;

        # Light hardening — MUST stay bwrap-compatible (steam-run).
        # Do NOT add NoNewPrivileges / PrivateMounts / strict sandboxing here.
        PrivateTmp = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ stateDir ];
        ProtectHome = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        UMask = "0027";
      } // server.extraServiceConfig;
    };

  # Optional systemd timer that periodically updates a server and restarts it
  mkUpdateTimer = name: server:
    let
      stateDir = stateDirOf name server;
      updateScript = mkUpdateScript name server;
    in
    lib.nameValuePair "game-server-${name}-update" {
      description = "steamcmd update for ${displayName name server}";
      after = [ "game-server-${name}.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = stateDir;
        ExecStart = updateScript;
        ExecStartPost = "${pkgs.systemd}/bin/systemctl try-restart game-server-${name}.service";
      };
    };

  mkUpdateTimerUnit = name: server:
    lib.nameValuePair "game-server-${name}-update" {
      description = "Timer for ${displayName name server} steamcmd updates";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = server.updateSchedule;
        Persistent = true;
      };
    };

  # Per-server A2S Prometheus exporter (metrics on 127.0.0.1:<exporterPort>)
  mkExporterUnit = name: server:
    let
      exporter = cfg.monitoring.exporter;
    in
    lib.nameValuePair "game-server-${name}-exporter" {
      description = "A2S Prometheus exporter for ${displayName name server}";
      wantedBy = [ "multi-user.target" ];
      after = [ "game-server-${name}.service" ];
      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        ExecStart = "${lib.getExe exporter} --address ${
            lib.escapeShellArg "${cfg.monitoring.listenAddress}:${toString server.monitoring.queryPort}"
          } --port ${toString server.monitoring.exporterPort}";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

  serverUnits = lib.mapAttrs' mkServerUnit enabledServers;

  timerUnits = lib.mapAttrs' mkUpdateTimerUnit
    (lib.filterAttrs (_: s: s.updateSchedule != null) enabledServers);

  timerServices = lib.mapAttrs'
    mkUpdateTimer
    (lib.filterAttrs (_: s: s.updateSchedule != null) enabledServers);

  exporterUnits = lib.mapAttrs'
    mkExporterUnit
    (lib.filterAttrs (_: s: s.monitoring.enable) enabledServers);
in
{
  config = lib.mkIf cfg.enable {
    systemd.services = lib.mkMerge [
      serverUnits
      timerServices
      (lib.mkIf cfg.monitoring.enable exporterUnits)
    ];

    systemd.timers = timerUnits;
  };
}
