{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.suwayomi;
  format = pkgs.formats.hocon { };

  configFile = format.generate "server.conf" (
    lib.pipe cfg.settings [
      (settings:
        lib.recursiveUpdate settings {
          server.basicAuthPasswordFile = null;
          server.basicAuthPassword =
            if settings.server.basicAuthEnabled then "$TACHIDESK_SERVER_BASIC_AUTH_PASSWORD" else null;
        }
      )
      (lib.filterAttrsRecursive (_: x: x != null))
    ]
  );
in
{
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.settings."10-suwayomi-server" = {
      "${cfg.dataDir}/.local/share/Tachidesk".d = {
        mode = "0700";
        inherit (cfg) user group;
      };
    };

    systemd.services.suwayomi-server = {
      description = "Suwayomi manga reader server";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      environment = {
        HOME = cfg.dataDir;
      };

      script = ''
        ${lib.optionalString cfg.settings.server.basicAuthEnabled ''
          TACHIDESK_SERVER_BASIC_AUTH_PASSWORD="$(<${cfg.settings.server.basicAuthPasswordFile})"
          export TACHIDESK_SERVER_BASIC_AUTH_PASSWORD
        ''}
        ${lib.getExe pkgs.envsubst} -i ${configFile} -o ${cfg.dataDir}/.local/share/Tachidesk/server.conf
        exec ${lib.getExe cfg.package} -Dsuwayomi.tachidesk.config.server.rootDir=${cfg.dataDir}
      '';

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "5s";
        StateDirectory = lib.mkIf (cfg.dataDir == "/var/lib/suwayomi-server") "suwayomi-server";
        StateDirectoryMode = "0700";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectHome = false;
        ProtectSystem = "strict";
        ReadWritePaths = [ cfg.dataDir ];
        LockPersonality = true;
        RestrictNamespaces = true;
        RestrictRealtime = true;
      };
    };
  };
}
