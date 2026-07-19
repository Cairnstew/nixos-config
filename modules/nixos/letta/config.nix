{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.letta;
  dbUrl =
    if cfg.database.url != null then cfg.database.url
    else "sqlite:///${cfg.dataDir}/letta.db";
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

    virtualisation.oci-containers.containers."letta" = {
      image = cfg.image;
      volumes = [ "${cfg.dataDir}:/app/data:rw" ] ++ cfg.extraVolumes;
      ports = [ "${toString cfg.port}:8283/tcp" ];
      environment = lib.filterAttrs (_: v: v != "") ({
        LETTA_DATABASE_URL = dbUrl;
        LETTA_DATA_DIR = "/app/data";
      } // lib.optionalAttrs cfg.ollama.enable {
        OPENAI_API_BASE = cfg.ollama.baseUrl;
        OPENAI_API_KEY = cfg.openaiCompat.apiKey;
        LETTA_DEFAULT_MODEL = cfg.ollama.defaultModel;
      } // cfg.extraEnvironment);
      log-driver = cfg.logDriver;
      extraOptions = [
        "--network-alias=${cfg.network.alias}"
        "--network=${cfg.network.name}"
      ];
    };

    # Register with reverse proxy
    my.services.proxy.upstreams.letta = {
      port = cfg.port;
      path = "/letta/";
      # Caddy's handle_path strips /letta prefix automatically.
      # WebSocket is auto-detected — no special config needed.
      extraLocations = [
        # Letta references /openapi.json in its response body.
        # Proxy it so the link works from the SPA at /letta/.
        ''
          handle /openapi.json {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
      ];
    };
  };
}
