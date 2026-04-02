{ config, lib, pkgs, ... }:

let
  cfg = config.my.virtualisation.docker;
in
{
  options.my.virtualisation.docker = {
    enable = lib.mkEnableOption "Docker daemon";

    enableOnBoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "When enabled, dockerd is started on boot.";
    };

    enableNvidiaContainerToolkit = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable the NVIDIA Container Toolkit, allowing Docker containers to
        access the host GPU. Requires hardware.nvidia.modesetting.enable = true.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.docker;
      defaultText = lib.literalExpression "pkgs.docker";
      description = "The Docker package to use.";
    };

    extraOptions = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "--ipv6";
      description = "Extra command-line options to pass to the Docker daemon.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.cni-plugins ]";
      description = "Extra packages to add to PATH for the Docker daemon process.";
    };

    listenOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "/run/docker.sock" ];
      example = [ "/run/docker.sock" "tcp://127.0.0.1:2375" ];
      description = "A list of unix sockets and/or tcp addresses that Docker should listen on.";
    };

    liveRestore = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable Docker live restore, keeping containers alive when the daemon is
        stopped or restarted. Alias of virtualisation.docker.daemon.settings.live-restore.
      '';
    };

    logDriver = lib.mkOption {
      type = lib.types.enum [
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
      description = "Which Docker log driver to use.";
    };

    storageDriver = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [
        "aufs"
        "btrfs"
        "devicemapper"
        "overlay"
        "overlay2"
        "zfs"
      ]);
      default = null;
      description = "Which Docker storage driver to use. null means Docker will choose automatically.";
    };

    autoPrune = {
      enable = lib.mkEnableOption "automatic Docker resource pruning";

      flags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "--filter=until=24h" ];
        description = "Extra flags passed to docker system prune.";
      };

      dates = lib.mkOption {
        type = lib.types.str;
        default = "weekly";
        example = "daily";
        description = ''
          How often to run docker system prune. Uses systemd calendar
          event format (see systemd.time(7)).
        '';
      };
    };

    daemon = {
      settings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        example = lib.literalExpression ''
          {
            fixed-cidr-v6 = "fd00::/80";
            ipv6 = true;
          }
        '';
        description = ''
          Docker daemon configuration as an attribute set. Written to
          /etc/docker/daemon.json. See the Docker documentation for
          available options.
        '';
      };
    };

    dataRoot = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/mnt/data/docker";
      description = "Root directory for Docker data (images, containers, volumes).";
    };

    rootless = {
      enable = lib.mkEnableOption "rootless Docker";

      setSocketVariable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Set the DOCKER_HOST environment variable to the rootless Docker
          socket path for login sessions.
        '';
      };

      daemon = {
        settings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = ''
            Rootless Docker daemon configuration as an attribute set.
            Written to the rootless daemon.json config file.
          '';
        };
      };
    };

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "alice" "bob" ];
      description = ''
        List of user accounts to add to the docker group, granting them
        permission to use the Docker daemon without sudo.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker = {
      enable = true;
      enableOnBoot = cfg.enableOnBoot;
      package = cfg.package;
      extraOptions = cfg.extraOptions;
      extraPackages = cfg.extraPackages;
      listenOptions = cfg.listenOptions;
      liveRestore = cfg.liveRestore;
      logDriver = cfg.logDriver;
      storageDriver = cfg.storageDriver;

      autoPrune = {
        enable = cfg.autoPrune.enable;
        flags = cfg.autoPrune.flags;
        dates = cfg.autoPrune.dates;
      };

      daemon.settings =
      cfg.daemon.settings
      // lib.optionalAttrs (cfg.dataRoot != null) {
        data-root = cfg.dataRoot;
      }
      // lib.optionalAttrs cfg.enableNvidiaContainerToolkit {
        features = {
          cdi = true;
        };
      };

      rootless = {
        enable = cfg.rootless.enable;
        setSocketVariable = cfg.rootless.setSocketVariable;
        daemon.settings = cfg.rootless.daemon.settings;
      };
    };

    hardware.nvidia-container-toolkit.enable = lib.mkForce cfg.enableNvidiaContainerToolkit;

    users.users = lib.genAttrs cfg.users (_: {
      extraGroups = [ "docker" ];
    });
  };
}
