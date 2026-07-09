{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.risuai;
  ollamaCfg = config.my.services.ollama;
in
{
  config = lib.mkIf cfg.enable {
    virtualisation.docker = lib.mkIf (cfg.backend == "docker") {
      enable = lib.mkDefault true;
      autoPrune.enable = lib.mkDefault cfg.autoPrune;
    };

    virtualisation.podman = lib.mkIf (cfg.backend == "podman") {
      enable = lib.mkDefault true;
      autoPrune.enable = lib.mkDefault cfg.autoPrune;
    };

    systemd.tmpfiles.rules = [ "d ${cfg.dataDir} 0755 root root -" ];

    virtualisation.oci-containers.backend = cfg.backend;

    virtualisation.oci-containers.containers."risuai" = {
      image = cfg.image;
      volumes = [ "${cfg.dataDir}:/app/data:rw" ] ++ cfg.extraVolumes;
      ports = [ "${toString cfg.port}:6001/tcp" ];
      environment = lib.filterAttrs (_: v: v != "") ({
        RISUAI_HOST = cfg.host;
        RISUAI_PORT = "6001";
      } // lib.optionalAttrs cfg.ollama.enable {
        OLLAMA_BASE_URL = cfg.ollama.baseUrl;
      } // lib.optionalAttrs (cfg.openaiCompat.apiBaseUrl != null) {
        OPENAI_API_BASE_URL = cfg.openaiCompat.apiBaseUrl;
        OPENAI_API_KEY = cfg.openaiCompat.apiKey;
      } // cfg.extraEnvironment);
      log-driver = cfg.logDriver;
      extraOptions = [
        "--network-alias=${cfg.network.alias}"
        "--network=${cfg.network.name}"
      ];
    };
  };
}
