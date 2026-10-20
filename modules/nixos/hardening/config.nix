{ config, lib, ... }:
let
  cfg = config.my.system.hardening;
  inherit (lib) mkIf mkMerge;

  # `systemd.services` keys are unit names WITHOUT the `.service` suffix.
  # Passing "sshd.service" here silently creates a bogus `sshd.service.service`
  # unit and leaves the real daemon unprotected (confirmed on server: the real
  # sshd had OOMScoreAdjust=0). Accept both spellings, normalize to the bare
  # unit name.
  unitName = unit: lib.removeSuffix ".service" unit;

  # Protect critical services: never OOM-killed by the kernel, never selected
  # by systemd-oomd, and maximum CPU scheduling priority.
  protectedDefs = lib.genAttrs (map unitName cfg.protectedUnits) (_: {
    serviceConfig = {
      OOMScoreAdjust = -1000;
      ManagedOOMPreference = "omit";
      CPUWeight = 1000;
    };
  });

  # Cap heavy services so they can't starve SSH of CPU time.
  cpuQuotaDefs = lib.mapAttrs'
    (unit: quota:
      lib.nameValuePair unit { serviceConfig.CPUQuota = quota; }
    )
    cfg.cpuQuota;

  joinRegex = patterns: lib.concatStringsSep "|" patterns;

  # earlyoom wants `--avoid REGEX` / `--prefer REGEX` as separate argv entries.
  earlyoomArgs =
    lib.optional (cfg.earlyoom.avoid != [ ]) "--avoid"
    ++ lib.optional (cfg.earlyoom.avoid != [ ]) (joinRegex cfg.earlyoom.avoid)
    ++ lib.optional (cfg.earlyoom.prefer != [ ]) "--prefer"
    ++ lib.optional (cfg.earlyoom.prefer != [ ]) (joinRegex cfg.earlyoom.prefer);
in
{
  config = mkIf cfg.enable {
    # ── zram compressed swap ───────────────────────────────────────────────
    zramSwap = mkIf cfg.zram.enable {
      enable = true;
      memoryPercent = cfg.zram.memoryPercent;
      algorithm = cfg.zram.algorithm;
      priority = cfg.zram.priority;
    };

    systemd = {
      # ── systemd-oomd: proactive OOM killing on root/system/user slices ───
      oomd = mkIf cfg.oomd.enable {
        enable = true;
        enableRootSlice = cfg.oomd.enableRootSlice;
        enableSystemSlice = cfg.oomd.enableSystemSlice;
        enableUserSlices = cfg.oomd.enableUserSlices;
        settings.OOM = {
          SwapUsedLimit = cfg.oomd.swapUsedLimit;
          DefaultMemoryPressureLimit = cfg.oomd.defaultMemoryPressureLimit;
          # Correct key is `...DurationSec=`. `...DurationUSec=` is not a
          # systemd-oomd option and was silently ignored (journal:
          # "Unknown key 'DefaultMemoryPressureDurationUSec' ... ignoring").
          DefaultMemoryPressureDurationSec = cfg.oomd.defaultMemoryPressureDurationSec;
        };
      };

      # NixOS sets ManagedOOMMemoryPressureLimit=80% on these slices, which
      # overrides oomd.conf's DefaultMemoryPressureLimit. Set the configured
      # limit explicitly so `defaultMemoryPressureLimit` actually takes effect.
      slices = mkMerge [
        (mkIf cfg.oomd.enable {
          "user".sliceConfig.ManagedOOMMemoryPressureLimit = cfg.oomd.defaultMemoryPressureLimit;
          "system".sliceConfig.ManagedOOMMemoryPressureLimit = cfg.oomd.defaultMemoryPressureLimit;
        })

        # Hard cgroup caps: a runaway nix evaluation (user session) or build
        # (nix-daemon) hits its own cgroup OOM killer instead of exhausting all
        # RAM and freezing the box. Percentages are of physical RAM.
        (mkIf cfg.workloadLimits.enable {
          "user".sliceConfig = {
            MemoryHigh = cfg.workloadLimits.userSliceMemoryHigh;
            MemoryMax = cfg.workloadLimits.userSliceMemoryMax;
          };
          "system".sliceConfig.MemoryMin = cfg.workloadLimits.systemSliceMemoryMin;
        })
      ];

      # ── Critical services: OOM/oomd protection + CPU priority ────────────
      # ── Cap heavy services via CPUQuota ──────────────────────────────────
      # ── Cap nix-daemon builds; prefer killing a build over a daemon ──────
      services = mkMerge [
        protectedDefs
        cpuQuotaDefs
        (mkIf cfg.workloadLimits.enable {
          nix-daemon.serviceConfig = {
            MemoryHigh = cfg.workloadLimits.nixDaemonMemoryHigh;
            MemoryMax = cfg.workloadLimits.nixDaemonMemoryMax;
            # Positive score: if a global OOM is unavoidable, the kernel should
            # pick a build process before sshd/tailscaled/logind.
            OOMScoreAdjust = 500;
          };
        })
      ];

      settings.Manager = mkIf (cfg.watchdog.runtimeSec != null) {
        RuntimeWatchdogSec = cfg.watchdog.runtimeSec;
      };
    };

    # ── earlyoom: fast global backstop ─────────────────────────────────────
    services.earlyoom = mkIf cfg.earlyoom.enable {
      enable = true;
      freeMemThreshold = cfg.earlyoom.freeMemThreshold;
      freeMemKillThreshold = cfg.earlyoom.freeMemKillThreshold;
      freeSwapThreshold = cfg.earlyoom.freeSwapThreshold;
      freeSwapKillThreshold = cfg.earlyoom.freeSwapKillThreshold;
      extraArgs = earlyoomArgs;
    };

    # ── Kernel VM tuning + out-of-band recovery ────────────────────────────
    boot.kernel.sysctl = mkMerge [
      (mkIf cfg.sysctls.enable {
        "vm.swappiness" = cfg.sysctls.swappiness;
        "vm.page-cluster" = cfg.sysctls.pageCluster;
        "vm.overcommit_memory" = if cfg.sysctls.strictOvercommit then 2 else 0;
        # Keep 0: rebooting on every OOM would turn a killed process into
        # downtime. Recovery is handled by the watchdog/sysrq instead.
        "vm.panic_on_oom" = 0;
      })
      (mkIf cfg.magicSysRq.enable {
        # 1 = all Magic SysRq functions. Default 16 allows sync only, so
        # Alt+SysRq+F/B (OOM-kill / reboot) do nothing from a PiKVM.
        "kernel.sysrq" = 1;
      })
    ];
  };
}
