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
      volumes = [ "${cfg.dataDir}:/app/save:rw" ] ++ cfg.extraVolumes;
      ports = [ "${toString cfg.port}:6001/tcp" ];
      environment = lib.filterAttrs (_: v: v != "") ({
        RISUAI_HOST = cfg.host;
        RISUAI_PORT = "6001";
        # Note: VITE_ env vars must be set at Vite build time, not container runtime.
        # Use `just risuai-image` to build the image with this baked in.
        # This runtime env var is a no-op but kept for documentation.
        VITE_RISU_LEGAL_CONFIGURED = if cfg.legalConfigured then "TRUE" else "FALSE";
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

    # Register with reverse proxy
    my.services.proxy.upstreams.risuai = {
      port = cfg.port;
      path = "/risuai/";
      # WebSocket auto-detected by Caddy — no special config needed.
      # Root-relative SPA paths proxy to RisuAI.
      extraLocations = [
        # SPA assets (JS/CSS chunks referenced with absolute paths)
        ''
        handle /assets/* {
          reverse_proxy 127.0.0.1:${toString cfg.port}
        }
        ''
        # API calls — catches /api/* (RisuAI's general API routes)
        ''
        handle /api/* {
          reverse_proxy 127.0.0.1:${toString cfg.port}
        }
        ''
        # Service worker
        ''
        handle /sw/* {
          reverse_proxy 127.0.0.1:${toString cfg.port}
        }
        ''
        # Hub proxy (character/asset hub)
        ''
        handle /hub-proxy/* {
          reverse_proxy 127.0.0.1:${toString cfg.port}
        }
        ''
        # Manifest and icons
        ''
        handle /manifest.json {
          reverse_proxy 127.0.0.1:${toString cfg.port}
        }
        ''
        ''
        handle /logo_* {
          reverse_proxy 127.0.0.1:${toString cfg.port}
        }
        ''
        ''
        handle /none.webp {
          reverse_proxy 127.0.0.1:${toString cfg.port}
        }
        ''
      ];
    };
  };
}
