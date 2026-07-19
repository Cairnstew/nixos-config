{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.services.jan;
  username = flake.config.me.username;
  userHome = "/home/${username}";
  janDataDir = "${userHome}/.local/share/Jan/data";

  janSettings = lib.recursiveUpdate
    {
      api_server = lib.optionalAttrs cfg.apiServer.enable {
        enabled = true;
        port = cfg.apiServer.port;
        host = cfg.apiServer.host;
      };
      engines = lib.optionalAttrs cfg.ollama.enable {
        ollama = {
          enabled = true;
          base_url = cfg.ollama.baseUrl;
        };
      };
    }
    cfg.extraSettings;

  janSettingsJson = pkgs.writeText "jan-settings.json" (builtins.toJSON janSettings);
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # Deploy settings.json and user service via home-manager
    home-manager.users.${username} = lib.mkIf cfg.apiServer.enable {
      home.file."${janDataDir}/settings.json" = {
        source = janSettingsJson;
        force = true;
      };

      systemd.user.services.jan = {
        Unit = {
          Description = "Jan API server (OpenAI-compatible)";
          After = [ "graphical-session.target" "network-online.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = "${lib.getExe cfg.package} serve --host ${cfg.apiServer.host} --port ${toString cfg.apiServer.port}";
          Restart = "on-failure";
          RestartSec = "5s";
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    };
  };
}
