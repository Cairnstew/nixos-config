{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.jan;

  janSettings = lib.recursiveUpdate {
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
  } cfg.extraSettings;

  janSettingsJson = pkgs.writeText "jan-settings.json" (builtins.toJSON janSettings);
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
      "d ${cfg.dataDir}/models 0755 root root -"
      "d ${cfg.dataDir}/threads 0755 root root -"
    ];

    systemd.services.jan = lib.mkIf cfg.apiServer.enable {
      description = "Jan API server (OpenAI-compatible)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/jan serve --host ${cfg.apiServer.host} --port ${toString cfg.apiServer.port}";
        Restart = "on-failure";
        RestartSec = "5s";
        DynamicUser = true;
        StateDirectory = "jan";
        WorkingDirectory = cfg.dataDir;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
      };
    };
  };
}
