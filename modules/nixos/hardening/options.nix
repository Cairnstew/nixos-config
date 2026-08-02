{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.system.hardening = {
    enable = mkEnableOption "memory/CPU pressure hardening (zram swap, systemd-oomd, OOM-protected SSH-critical services)";

    # ── zram compressed swap ───────────────────────────────────────────────
    zram = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable zram compressed in-RAM swap. Gives the OOM killer and
          systemd-oomd a reclaim target before memory pressure can freeze
          the box — the primary guard against a runaway process making SSH
          unreachable.
        '';
      };

      memoryPercent = mkOption {
        type = types.int;
        default = 50;
        description = "Maximum total zram size as a percentage of RAM.";
      };

      algorithm = mkOption {
        type = types.str;
        default = "zstd";
        description = "Compression algorithm for zram (zstd, lz4, lzo-rle).";
      };

      priority = mkOption {
        type = types.int;
        default = 100;
        description = "Swap priority for zram devices (higher = preferred over disk swap).";
      };
    };

    # ── systemd-oomd proactive OOM killing ─────────────────────────────────
    oomd = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable systemd-oomd to kill the worst offender under memory pressure instead of letting the box freeze.";
      };

      enableRootSlice = mkOption {
        type = types.bool;
        default = true;
        description = "Enable oomd on the root slice (-.slice) — the catch-all backstop.";
      };

      enableSystemSlice = mkOption {
        type = types.bool;
        default = true;
        description = "Enable oomd on system.slice so runaway daemons get killed.";
      };

      enableUserSlices = mkOption {
        type = types.bool;
        default = true;
        description = "Enable oomd on user@.slice so runaway user processes get killed.";
      };

      swapUsedLimit = mkOption {
        type = types.str;
        default = "90%";
        description = "oomd kills a cgroup when swap usage exceeds this (SwapUsedLimit).";
      };

      defaultMemoryPressureLimit = mkOption {
        type = types.str;
        default = "60%";
        description = "oomd kills a cgroup when memory pressure exceeds this for the duration below.";
      };

      defaultMemoryPressureDurationUSec = mkOption {
        type = types.str;
        default = "30s";
        description = "How long memory pressure must exceed the limit before oomd acts.";
      };
    };

    # ── critical services that must never die ──────────────────────────────
    protectedUnits = mkOption {
      type = types.listOf types.str;
      default = [ "sshd.service" "tailscaled.service" ];
      description = ''
        Systemd units that get OOMScoreAdjust=-1000 (never selected by the OOM
        killer) and CPUWeight=1000 (maximum scheduling priority) so remote
        access stays available even under extreme pressure.
      '';
    };

    # ── cap heavy services so they can't starve SSH ────────────────────────
    cpuQuota = mkOption {
      type = types.attrsOf types.str;
      default = {
        "docker-ollama" = "400%";
        "podman-ollama" = "400%";
        "comfy-ui" = "400%";
        "jellyfin" = "300%";
      };
      description = ''
        CPUQuota (e.g. '400%' = 4 cores) applied to the named systemd units,
        capping memory/CPU-hungry services so they can't starve SSH of
        scheduling time. Override per host: drop entries, or change the
        percentage to match the box's core count (leave at least ~1 core
        headroom: '400%' on an 8-core box → 4 cores for the system).
      '';
      example = {
        "docker-ollama" = "600%";
        "jellyfin" = "200%";
      };
    };

    # ── kernel VM tuning ───────────────────────────────────────────────────
    sysctls = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Apply the vm.* sysctls below.";
      };

      swappiness = mkOption {
        type = types.int;
        default = 100;
        description = "High swappiness pushes memory pressure into compressed zram swap instead of blocking on reclaim.";
      };

      pageCluster = mkOption {
        type = types.int;
        default = 0;
        description = "vm.page-cluster. 0 is recommended for zram (disable sequential swap readahead).";
      };

      strictOvercommit = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Set vm.overcommit_memory=2 (strict, no overcommit) instead of the
          heuristic default. WARNING: can break applications that rely on
          overcommit. Default false — zram + oomd is the safer path.
        '';
      };
    };
  };
}
