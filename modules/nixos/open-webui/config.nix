{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.open-webui;
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

    virtualisation.oci-containers.containers."open-webui" = {
      image = cfg.image;
      volumes = [ "${cfg.dataDir}:/app/backend/data:rw" ] ++ cfg.extraVolumes;
      ports = [ "${toString cfg.port}:${toString cfg.containerPort}/tcp" ];
      environment = lib.filterAttrs (_: v: v != "") ({
        OLLAMA_BASE_URL = if cfg.ollama.enable then cfg.ollama.baseUrl else "";
        WEBUI_NAME = "Open WebUI";
        WEBUI_PORT = toString cfg.containerPort;
        WEBUI_SECRET_KEY = "";
        ANONYMIZED_TELEMETRY = "false";
        RAG_EMBEDDING_MODEL = cfg.rag.embeddingModel;
        RAG_TOP_K = toString cfg.rag.topK;
      } // lib.optionalAttrs cfg.webSearch.enable {
        WEBUI_SEARCH_PROVIDER = cfg.webSearch.provider;
        SEARXNG_BASE_URL = lib.optionalString (cfg.webSearch.provider == "searxng" && cfg.webSearch.searxngBaseUrl != null) cfg.webSearch.searxngBaseUrl;
        WEBUI_SEARCH_API_KEY = cfg.webSearch.apiKey;
      } // lib.optionalAttrs (cfg.trustedProxies != [ ]) {
        TRUSTED_PROXIES = builtins.concatStringsSep "," cfg.trustedProxies;
      } // cfg.extraEnvironment);
      log-driver = cfg.logDriver;
      extraOptions = [
        "--network-alias=${cfg.network.alias}"
        "--network=${cfg.network.name}"
      ];
    };

    # Register with reverse proxy
    my.services.proxy.upstreams.open-webui = {
      port = cfg.port;
      path = "/chat/";
      websocket = true;
      extraConfig = ''
        proxy_buffering off;
        client_max_body_size 0;
      '';
    };
  };
}
