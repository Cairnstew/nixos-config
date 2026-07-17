{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.services.chatterbox-tts;
  stateDir = cfg.stateDir;
  selfPkgs = flake.inputs.self.packages.${pkgs.system};
in
{
  config = lib.mkIf cfg.enable {
    my.services.chatterbox-tts.package = lib.mkDefault selfPkgs.chatterbox-tts;

    users.users = lib.mkIf (cfg.user == "chatterbox-tts") {
      chatterbox-tts = {
        isSystemUser = true;
        group = cfg.group;
        description = "Chatterbox TTS service user";
        home = stateDir;
        createHome = true;
      };
    };

    users.groups = lib.mkIf (cfg.group == "chatterbox-tts") {
      chatterbox-tts = { };
    };

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${stateDir}/logs 0750 ${cfg.user} ${cfg.group} -"
      "d ${stateDir}/voices 0750 ${cfg.user} ${cfg.group} -"
      "d ${stateDir}/reference_audio 0750 ${cfg.user} ${cfg.group} -"
      "d ${stateDir}/outputs 0750 ${cfg.user} ${cfg.group} -"
      "d ${stateDir}/model_cache 0750 ${cfg.user} ${cfg.group} -"
    ];

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    # Register with reverse proxy
    my.services.proxy.upstreams.chatterbox-tts = {
      port = cfg.port;
      path = "/tts/";
      # WebSocket auto-detected by Caddy.
    };
  };
}
