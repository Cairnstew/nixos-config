{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.virtualisation.docker;

  # Check if NVIDIA Container Toolkit is actually enabled
  nvidiaToolkitEnabled = config.hardware.nvidia-container-toolkit.enable or false;
  explicitlyEnabled = cfg.enableNvidiaContainerToolkit;
in
{
  # ── L0: Nix Assertions ────────────────────────────────────────────────────
  assertions = [
    {
      assertion = !(cfg.enable && cfg.rootless.enable) || cfg.users == [ ];
      message = ''
        Docker rootless mode does not use the docker group for permissions.
        When rootless mode is enabled, `users` should be empty as access
        is managed per-user through the rootless daemon.
      '';
    }
    {
      assertion = !(cfg.enable && explicitlyEnabled) || nvidiaToolkitEnabled || !explicitlyEnabled;
      message = ''
        `my.virtualisation.docker.enableNvidiaContainerToolkit` is enabled but
        NVIDIA Container Toolkit is not configured at the system level.

        To use NVIDIA GPUs in Docker:
        1. Enable a GPU profile: `my.profiles.gpu.nvidia.enable = true;`
           or `my.profiles.gpu.nvidia-headless.enable = true;`
        2. This will configure both drivers and the container toolkit

        Or manually configure:
        - `hardware.nvidia-container-toolkit.enable = true;`
        - Proper NVIDIA driver configuration
      '';
    }
    {
      assertion = !cfg.enable ||
        !(builtins.elem "tcp://0.0.0.0:2375" cfg.listenOptions) ||
        (builtins.elem "tcp://127.0.0.1:2375" cfg.listenOptions);
      message = ''
        Docker is configured to listen on all interfaces (0.0.0.0:2375) without
        authentication. This is a security risk. Use 127.0.0.1 or configure
        TLS authentication.
      '';
    }
  ];

  # ── L1: systemd Service Health Checks ────────────────────────────────────
  systemd.services.docker-health-check = mkIf cfg.enable {
    description = "Health check for Docker daemon";
    after = [ "docker.service" "network-online.target" ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "docker-health-check" ''
        set -euo pipefail
        TIMEOUT=60
        ELAPSED=0

        echo "Checking Docker daemon status..."

        while [ $ELAPSED -lt $TIMEOUT ]; do
          if ${pkgs.curl}/bin/curl -s --unix-socket /run/docker.sock http://localhost/_ping 2>/dev/null | grep -q "OK"; then
            echo "Docker daemon is healthy"
            exit 0
          fi
          sleep 2
          ELAPSED=$((ELAPSED + 2))
        done

        echo "WARNING: Docker daemon did not become healthy within $TIMEOUT seconds"
        exit 0  # Don't fail boot, just warn
      '';
    };
  };

  # ── L2: Smoke Test Service ───────────────────────────────────────────────
  systemd.services.docker-smoke-test = mkIf cfg.enable {
    description = "Smoke test for Docker installation";
    # Not enabled by default - run manually: systemctl start docker-smoke-test

    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "docker-smoke-test" ''
        set -euo pipefail
        echo "=== Docker Smoke Test ==="

        # Check docker binary exists
        if ! command -v ${pkgs.docker}/bin/docker >/dev/null 2>&1; then
          echo "FAIL: docker binary not found"
          exit 1
        fi
        echo "PASS: docker binary found"

        # Check dockerd binary exists
        if ! command -v ${pkgs.docker}/bin/dockerd >/dev/null 2>&1; then
          echo "FAIL: dockerd binary not found"
          exit 1
        fi
        echo "PASS: dockerd binary found"

        # Check docker service is active
        if ! systemctl is-active --quiet docker; then
          echo "FAIL: docker service is not active"
          exit 1
        fi
        echo "PASS: docker service is active"

        # Check docker socket exists
        if [ ! -S /run/docker.sock ]; then
          echo "FAIL: docker socket not found at /run/docker.sock"
          exit 1
        fi
        echo "PASS: docker socket exists"

        # Test docker version command
        if ! ${pkgs.docker}/bin/docker version --format '{{.Server.Version}}' >/dev/null 2>&1; then
          echo "FAIL: docker version command failed"
          exit 1
        fi
        echo "PASS: docker version responds"

        # Test docker info
        if ! ${pkgs.docker}/bin/docker info >/dev/null 2>&1; then
          echo "FAIL: docker info command failed"
          exit 1
        fi
        echo "PASS: docker info responds"

        # Test basic container run (hello-world)
        echo "Testing container execution..."
        if ${pkgs.docker}/bin/docker run --rm hello-world >/dev/null 2>&1; then
          echo "PASS: container execution works"
        else
          echo "WARNING: container execution test skipped or failed (may require network)"
        fi

        # Check NVIDIA support if enabled
        if [ "${if nvidiaToolkitEnabled then "true" else "false"}" = "true" ]; then
          echo "Checking NVIDIA Container Toolkit..."
          
          if command -v ${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk >/dev/null 2>&1; then
            echo "PASS: nvidia-ctk binary found"
          else
            echo "FAIL: nvidia-ctk binary not found"
          fi

          if [ -f /var/run/cdi/nvidia.yaml ]; then
            echo "PASS: CDI specification exists"
          else
            echo "INFO: CDI specification not yet generated (may require driver)"
          fi

          # Check if docker can see nvidia runtime
          if ${pkgs.docker}/bin/docker info 2>/dev/null | grep -q "nvidia"; then
            echo "PASS: nvidia runtime visible to docker"
          else
            echo "INFO: nvidia runtime not yet configured"
          fi
        fi

        # Check auto-prune timer if enabled
        if [ "${if cfg.autoPrune.enable then "true" else "false"}" = "true" ]; then
          if systemctl list-timers docker-prune.timer >/dev/null 2>&1; then
            echo "PASS: docker-prune timer exists"
          else
            echo "INFO: docker-prune timer not found"
          fi
        fi

        # Check rootless mode if enabled
        if [ "${if cfg.rootless.enable then "true" else "false"}" = "true" ]; then
          if systemctl --user list-unit-files docker.service >/dev/null 2>&1 || \
             [ -S "$HOME/.docker/run/docker.sock" ]; then
            echo "PASS: rootless docker appears configured"
          else
            echo "INFO: rootless docker socket not found"
          fi
        fi

        echo "=== Smoke Test Complete ==="
      '';
    };
  };
}
