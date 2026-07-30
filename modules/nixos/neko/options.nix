{ config, lib, pkgs, ... }:
{
  options.my.services.neko = {
    enable = lib.mkEnableOption "Neko remote browser (WebRTC-streamed headful Firefox)";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/m1k1o/neko/firefox:latest";
      description = "Neko OCI image. CPU-only base. GPU-tagged variants exist (:nvidia, etc.).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Host port for the Neko HTTP/WebSocket control interface.";
    };

    webrtcPortRange = {
      from = lib.mkOption {
        type = lib.types.port;
        default = 52000;
        description = "Start of the WebRTC ephemeral UDP port range (NEKO_WEBRTC_EPR start).";
      };
      to = lib.mkOption {
        type = lib.types.port;
        default = 52100;
        description = "End of the WebRTC ephemeral UDP port range (NEKO_WEBRTC_EPR end).";
      };
    };

    natIp = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "100.78.102.28";
      description = ''
        IP address sent to clients in WebRTC ICE candidates (NEKO_WEBRTC_NAT1TO1).
        Defaults to the server's Tailscale IP (100.78.102.28) because Neko is
        served exclusively over the tailnet. Leaving this null causes Neko to
        auto-detect the public IP, which is wrong when behind NAT — the client
        would receive a public-side IP that doesn't route to the container,
        breaking WebRTC connectivity. Set to the Tailscale IP for tailnet-only
        access, or to a public IP if exposed via tailscale funnel.
      '';
    };

    adminPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/agenix/neko-admin-password";
      description = ''
        File containing the Neko admin password (NEKO_MEMBER_MULTIUSER_ADMIN_PASSWORD).
        Use config.age.secrets."neko-admin-password".path.
      '';
    };

    userPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/agenix/neko-user-password";
      description = ''
        File containing the Neko user password (NEKO_MEMBER_MULTIUSER_USER_PASSWORD).
        Use config.age.secrets."neko-user-password".path.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to open the WebRTC UDP port range in the host firewall.
        Default false because Neko is served over Tailscale and tailscale0
        is a trusted interface (bypasses the NixOS firewall). Only set true
        if clients connect from outside the tailnet.
      '';
    };

    shmSize = lib.mkOption {
      type = lib.types.str;
      default = "2gb";
      description = ''
        Size of /dev/shm in the container (Docker --shm-size).
        Firefox/Chromium use shared memory for rendering; 2gb is the
        upstream-recommended value from Neko's docker-compose.yaml.
      '';
    };

    desktopScreen = lib.mkOption {
      type = lib.types.str;
      default = "1920x1080@30";
      description = "Desktop resolution and refresh rate (NEKO_DESKTOP_SCREEN).";
    };

    backend = lib.mkOption {
      type = lib.types.enum [ "docker" "podman" ];
      default = "docker";
      description = "OCI container backend to use.";
    };

    network = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "neko-net";
        description = "Docker network name.";
      };
      alias = lib.mkOption {
        type = lib.types.str;
        default = "neko";
        description = "Container network alias.";
      };
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables for the container.";
    };

    extraVolumes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra volume mounts for the container.";
    };

    logDriver = lib.mkOption {
      type = lib.types.str;
      default = "journald";
      description = "Logging driver for the container.";
    };

    autoPrune = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable automatic Docker system pruning.";
    };

    restart = {
      policy = lib.mkOption { type = lib.types.str; default = "always"; };
      maxDelaySec = lib.mkOption { type = lib.types.str; default = "1m"; };
      delaySec = lib.mkOption { type = lib.types.str; default = "100ms"; };
      steps = lib.mkOption { type = lib.types.int; default = 9; };
    };
  };
}
