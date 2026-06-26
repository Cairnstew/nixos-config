{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.suwayomi;
  format = pkgs.formats.hocon { };

  hasAuth = cfg.settings.server.authMode != "none";

  configFile = format.generate "server.conf" (
    lib.pipe cfg.settings [
      (settings:
        lib.recursiveUpdate settings {
          server.authPasswordFile = null;
          server.authPassword =
            if hasAuth then "$TACHIDESK_SERVER_AUTH_PASSWORD" else null;
        }
      )
      (lib.filterAttrsRecursive (_: x: x != null))
    ]
  );
in
{
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.settings."10-suwayomi-server" =
      let
        extraDirs = builtins.listToAttrs (map
          (p: {
            name = p;
            value.d = {
              mode = "0700";
              inherit (cfg) user group;
            };
          })
          cfg.extraReadWritePaths);
      in
      {
        "${cfg.dataDir}/.local/share/Tachidesk".d = {
          mode = "0700";
          inherit (cfg) user group;
        };
      } // extraDirs;

    systemd.services.suwayomi-server = {
      description = "Suwayomi manga reader server";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      environment = {
        HOME = cfg.dataDir;
      };

      script = ''
        ${lib.optionalString hasAuth ''
          TACHIDESK_SERVER_AUTH_PASSWORD="$(<${cfg.settings.server.authPasswordFile})"
          export TACHIDESK_SERVER_AUTH_PASSWORD
        ''}
        CONF="${cfg.dataDir}/.local/share/Tachidesk/server.conf"
        if [ ! -f "$CONF" ]; then
          ${lib.getExe pkgs.envsubst} -i ${configFile} -o "$CONF"
        fi
        exec ${lib.getExe cfg.package} -Dsuwayomi.tachidesk.config.server.rootDir=${cfg.dataDir}
      '';

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;

        ExecStartPre = [
          "+${pkgs.writeShellScript "suwayomi-pre-start" ''
            set -eu
            mkdir -p "${cfg.dataDir}/.local/share/Tachidesk"
            chown -R "${cfg.user}:${cfg.group}" "${cfg.dataDir}"
            ${lib.concatStringsSep "\n" (map (p: ''
              mkdir -p "${p}" 2>/dev/null || true
              chown "${cfg.user}:${cfg.group}" "${p}" 2>/dev/null || true
            '') cfg.extraReadWritePaths)}
          ''}"
        ];
        Type = "simple";
        Restart = "on-failure";
        RestartSec = "5s";
        StateDirectory = lib.mkIf (cfg.dataDir == "/var/lib/suwayomi-server") "suwayomi-server";
        StateDirectoryMode = "0700";
        NoNewPrivileges = true;
        ProtectHome = false;
      };
    };
  };
}
