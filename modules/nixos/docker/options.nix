{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types literalExpression;
in
{
  options.my.virtualisation.docker = {
    enable = mkEnableOption "Docker container runtime and daemon";

    enableOnBoot = mkOption {
      type = types.bool;
      default = true;
      description = "Start the Docker daemon automatically on boot.";
    };

    enableNvidiaContainerToolkit = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable NVIDIA Container Toolkit support in Docker.

        ::: {.note}
        For most users, enabling {option}`my.profiles.gpu.nvidia.enable`
        or {option}`my.profiles.gpu.nvidia-headless.enable` is sufficient.
        These profiles automatically configure both drivers and container toolkit.
        :::

        This option only configures Docker to work with the toolkit - you still
        need to enable the toolkit at the system level. For manual configuration:

        ```nix
        # Enable NVIDIA drivers and toolkit
        my.profiles.gpu.nvidia.enable = true;
        
        # Or manually:
        hardware.nvidia-container-toolkit.enable = true;
        my.virtualisation.docker.enableNvidiaContainerToolkit = true;
        ```

        The toolkit uses CDI (Container Device Interface) for modern GPU access.
      '';
    };

    package = mkOption {
      type = types.package;
      default = pkgs.docker;
      defaultText = literalExpression "pkgs.docker";
      description = "The Docker package to use.";
    };

    extraOptions = mkOption {
      type = types.str;
      default = "";
      example = "--ipv6 --mtu=1450";
      description = "Additional command-line options to pass to the Docker daemon.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression "[ pkgs.cni-plugins pkgs.docker-compose ]";
      description = "Extra packages to add to the Docker daemon's PATH.";
    };

    listenOptions = mkOption {
      type = types.listOf types.str;
      default = [ "/run/docker.sock" ];
      example = [ "/run/docker.sock" "tcp://127.0.0.1:2375" ];
      description = ''
        List of Unix sockets and/or TCP addresses the Docker daemon should listen on.
        Be cautious with TCP bindings as they bypass standard Unix permission controls.
      '';
    };

    liveRestore = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Keep containers running when the Docker daemon is stopped or restarted.
        This is the default behavior and improves container uptime during updates.
      '';
    };

    logDriver = mkOption {
      type = types.enum [
        "none"
        "json-file"
        "syslog"
        "journald"
        "gelf"
        "fluentd"
        "awslogs"
        "splunk"
        "etwlogs"
        "gcplogs"
        "local"
      ];
      default = "journald";
      description = ''
        Default logging driver for containers.
        'journald' integrates with systemd for centralized logging.
      '';
    };

    storageDriver = mkOption {
      type = types.nullOr (types.enum [
        "aufs"
        "btrfs"
        "devicemapper"
        "overlay"
        "overlay2"
        "zfs"
      ]);
      default = null;
      description = ''
        Storage driver for Docker images and containers.
        Null lets Docker automatically select the best driver for your system.
        overlay2 is recommended for most modern systems.
      '';
    };

    autoPrune = {
      enable = mkEnableOption "automatic cleanup of unused Docker resources";

      flags = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "--filter=until=24h" "--filter=label!=keep" ];
        description = "Extra flags passed to `docker system prune`.";
      };

      dates = mkOption {
        type = types.str;
        default = "weekly";
        example = "daily";
        description = ''
          Systemd calendar expression for when to run pruning.
          See {manpage}`systemd.time(7)` for format details.
        '';
      };
    };

    daemon = {
      settings = mkOption {
        type = types.attrs;
        default = { };
        example = literalExpression ''
          {
            fixed-cidr-v6 = "fd00::/80";
            ipv6 = true;
            "default-address-pools" = [
              { base = "172.30.0.0/16"; size = 24; }
            ];
          }
        '';
        description = ''
          Docker daemon configuration as an attribute set.
          Written to `/etc/docker/daemon.json`.
          See the Docker documentation for all available options.
        '';
      };
    };

    dataRoot = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/mnt/data/docker";
      description = ''
        Root directory for Docker data (images, containers, volumes).
        Useful for moving Docker storage to a larger disk.
      '';
    };

    rootless = {
      enable = mkEnableOption "rootless Docker mode";

      setSocketVariable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Set the DOCKER_HOST environment variable to point to the rootless
          Docker socket for login sessions.
        '';
      };

      daemon = {
        settings = mkOption {
          type = types.attrs;
          default = { };
          description = ''
            Rootless Docker daemon configuration.
            Written to the rootless daemon.json config file.
          '';
        };
      };
    };

    users = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "alice" "bob" ];
      description = ''
        List of user accounts to add to the `docker` group.
        Members can use Docker without sudo.
      '';
    };
  };
}
