{ config, lib, pkgs, flake, ... }:
let
  inherit (lib) mkIf mkMerge mkDefault;
  cfg = config.my.virtualisation.docker;

  # Check if NVIDIA Container Toolkit is already enabled at the system level
  # The graphics.nix module or nvidia profiles should enable this
  nvidiaToolkitEnabled = config.hardware.nvidia-container-toolkit.enable or false;

  # Users can also explicitly request NVIDIA support in Docker
  # This requires them to also configure NVIDIA drivers separately
  explicitlyEnabled = cfg.enableNvidiaContainerToolkit;
in
{
  config = mkIf cfg.enable (mkMerge [
    # ── Core Docker Configuration ─────────────────────────────────────────────
    {
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
          // (mkIf (cfg.dataRoot != null) {
            data-root = cfg.dataRoot;
          });

        rootless = {
          enable = cfg.rootless.enable;
          setSocketVariable = cfg.rootless.setSocketVariable;
          daemon.settings = cfg.rootless.daemon.settings;
        };
      };

      # Add users to docker group
      users.users = lib.genAttrs cfg.users (_: {
        extraGroups = [ "docker" ];
      });
    }

    # ── NVIDIA Container Toolkit (CDI-based) ──────────────────────────────────
    # Only configure Docker for NVIDIA if the toolkit is enabled system-wide
    (mkIf nvidiaToolkitEnabled {
      # Add toolkit packages to Docker's PATH
      virtualisation.docker.extraPackages = [
        pkgs.nvidia-container-toolkit
      ];

      # Configure Docker daemon for CDI (Container Device Interface)
      # This is the modern, recommended way to enable GPU access in containers
      virtualisation.docker.daemon.settings = {
        features = {
          cdi = true;
        };
        cdi-spec-dirs = [ "/var/run/cdi" ];
      };

      # systemd service to ensure nvidia-ctk runtime is configured
      # and CDI specs are generated
      systemd.services.docker-nvidia-setup = {
        description = "Configure NVIDIA Container Toolkit for Docker";
        after = [ "docker.service" ];
        requires = [ "docker.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "docker-nvidia-setup" ''
            set -euo pipefail

            # Wait for Docker socket to be available
            for i in {1..30}; do
              if [ -S /run/docker.sock ]; then
                break
              fi
              echo "Waiting for Docker socket..."
              sleep 1
            done

            # Configure nvidia-ctk for Docker if not already done
            if ! ${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk runtime list 2>/dev/null | grep -q docker; then
              echo "Configuring NVIDIA Container Toolkit for Docker..."
              ${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk runtime configure --runtime=docker || echo "nvidia-ctk configure may require drivers to be loaded"

              # Reload Docker to pick up new runtime
              systemctl reload docker 2>/dev/null || echo "Docker reload may require manual restart"
            fi

            # Ensure CDI spec is generated
            if [ ! -f /var/run/cdi/nvidia.yaml ]; then
              echo "Generating CDI specification..."
              mkdir -p /var/run/cdi
              ${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk cdi generate --output=/var/run/cdi/nvidia.yaml 2>/dev/null || echo "CDI generation may require NVIDIA drivers"
            fi

            echo "NVIDIA Container Toolkit configuration complete"
          '';
        };
      };
    })

    # ── Explicit NVIDIA Request (with warning) ────────────────────────────────
    # If user explicitly enabled but toolkit isn't configured, warn them
    (mkIf (explicitlyEnabled && !nvidiaToolkitEnabled) {
      warnings = [
        ''
          `my.virtualisation.docker.enableNvidiaContainerToolkit` is enabled but
          `hardware.nvidia-container-toolkit.enable` is not set.

          To use NVIDIA GPUs in Docker containers, you also need to:
          1. Enable NVIDIA drivers: `my.profiles.gpu.nvidia.enable = true;`
             or `my.profiles.gpu.nvidia-headless.enable = true;`
          2. Or manually enable: `hardware.nvidia-container-toolkit.enable = true;`

          Note: Ensure you have proper NVIDIA drivers configured.
        ''
      ];
    })
  ]);
}
