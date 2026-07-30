{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.neko;
  eprRange = "${toString cfg.webrtcPortRange.from}-${toString cfg.webrtcPortRange.to}";
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

    systemd.tmpfiles.rules = [ "d /run/neko 0755 root root -" ];

    virtualisation.oci-containers.backend = cfg.backend;

    virtualisation.oci-containers.containers."neko" = {
      image = cfg.image;
      volumes = cfg.extraVolumes;
      ports = [
        "${toString cfg.port}:8080/tcp"
        "${eprRange}:${eprRange}/udp"
      ];
      environment = lib.filterAttrs (_: v: v != "") ({
        NEKO_SERVER_BIND = ":8080";
        NEKO_DESKTOP_SCREEN = cfg.desktopScreen;
        NEKO_WEBRTC_EPR = eprRange;
        NEKO_WEBRTC_ICELITE = "1";
      } // lib.optionalAttrs (cfg.natIp != null) {
        NEKO_WEBRTC_NAT1TO1 = cfg.natIp;
      } // cfg.extraEnvironment);
      log-driver = cfg.logDriver;
      extraOptions = [
        "--shm-size=${cfg.shmSize}"
        "--network-alias=${cfg.network.alias}"
        "--network=${cfg.network.name}"
      ] ++ lib.optionals (cfg.adminPasswordFile != null || cfg.userPasswordFile != null) [
        "--env-file=/run/neko/env"
      ];
    };

    networking.firewall.allowedUDPPortRanges = lib.mkIf cfg.openFirewall [
      {
        from = cfg.webrtcPortRange.from;
        to = cfg.webrtcPortRange.to;
      }
    ];

    my.services.proxy.upstreams.neko = {
      host = "127.0.0.1";
      port = cfg.port;
      path = "/neko/";
      # trustProxy = null (default). Neko's Go backend handles
      # X-Forwarded-For transparently — it does not need an opt-in
      # trust proxy env var like Express (TRUST_PROXY) or uvicorn
      # (FORWARDED_ALLOW_IPS). The trustProxy enum intentionally
      # does not include a Go option because there's no env var to set.
      # Caddy sets X-Forwarded-For by default on all reverse_proxy
      # directives, and Go's http.Handler reads it without ceremony.
      # Neko's SPA loads JS/CSS/assets from root-relative paths
      # (/js/*, /css/*, etc.) which break under handle_path prefix
      # stripping. These are proxied via extraLocations below.
      # Neko's SPA is served at root (handle_path strips /neko/ prefix),
      # so its WebSocket, API, and asset URLs are root-relative.
      # These extraLocations catch those root-relative paths before
      # they fall through to the dashboard handler.
      extraLocations = [
        # WebSocket signaling — Neko connects at /ws (root relative)
        ''
          handle /ws/* {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
        # SPA JS/CSS assets
        ''
          handle /js/* {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
        ''
          handle /css/* {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
        # Static assets at root
        ''
          handle /*.png {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
        ''
          handle /*.svg {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
        ''
          handle /*.ico {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
        ''
          handle /site.webmanifest {
            reverse_proxy 127.0.0.1:${toString cfg.port}
          }
        ''
      ];
    };
  };
}
