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

    # Connect to ollama-net so the container can resolve ollama:11434
    systemd.services."${cfg.backend}-open-webui-ollama-net" = lib.mkIf cfg.ollama.enable {
      description = "Connect open-webui container to ollama-net";
      after = [ "${cfg.backend}-open-webui.service" ];
      wants = [ "${cfg.backend}-open-webui.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.writeShellScript "open-webui-join-ollama-net" ''
          ${if cfg.backend == "docker" then "${pkgs.docker}/bin/docker" else "${pkgs.podman}/bin/podman"} network connect ollama-net open-webui 2>/dev/null || true
        ''}";
      };
    };

    # Register with reverse proxy
    my.services.proxy.upstreams.open-webui = {
      port = cfg.port;
      displayName = "Open WebUI";
      path = "/chat/";
      # Caddy's handle_path strips /chat prefix automatically.
      # WebSocket is auto-detected — no special config needed.
      # SvelteKit root-relative routes are handled via extraLocations below.
      extraLocations = [
        # REST API v1 — specific path so it doesn't conflict with RisuAI's /api/
        ''
          handle /api/v1/* {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
        # SvelteKit internal assets and static files
        ''
          handle /_app/* {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
        ''
          handle /static/* {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
        # WebSocket and streaming
        ''
          handle /ws/* {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
        # SvelteKit page routes (SPA navigation targets)
        ''
          handle /auth/* {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
        ''
          handle /c/* {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
        ''
          handle /workspace/* {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
        ''
          handle /admin/* {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
        ''
          handle /models* {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
        ''
          handle /knowledge* {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
        ''
          handle /tools* {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
      ];
    };
  };
}
