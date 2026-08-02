{ config, lib, ... }:
let
  cfg = config.my.system.hardening;
  inherit (lib) mkIf mkMerge;

  # Protect critical services: never OOM-killed + maximum CPU scheduling priority.
  protectedDefs = lib.genAttrs cfg.protectedUnits (unit: {
    serviceConfig = {
      OOMScoreAdjust = -1000;
      CPUWeight = 1000;
    };
  });

  # Cap heavy services so they can't starve SSH of CPU time.
  cpuQuotaDefs = lib.mapAttrs'
    (unit: quota:
      lib.nameValuePair unit { serviceConfig.CPUQuota = quota; }
    )
    cfg.cpuQuota;
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

    # ── systemd-oomd: proactive OOM killing on root/system/user slices ─────
    systemd.oomd = mkIf cfg.oomd.enable {
      enable = true;
      enableRootSlice = cfg.oomd.enableRootSlice;
      enableSystemSlice = cfg.oomd.enableSystemSlice;
      enableUserSlices = cfg.oomd.enableUserSlices;
      settings.OOM = {
        SwapUsedLimit = cfg.oomd.swapUsedLimit;
        DefaultMemoryPressureLimit = cfg.oomd.defaultMemoryPressureLimit;
        DefaultMemoryPressureDurationUSec = cfg.oomd.defaultMemoryPressureDurationUSec;
      };
    };

    # ── Critical services: OOMScoreAdjust=-1000 + CPUWeight=1000 ───────────
    # ── Cap heavy services via CPUQuota ────────────────────────────────────
    systemd.services = mkMerge [ protectedDefs cpuQuotaDefs ];

    # ── Kernel VM tuning ───────────────────────────────────────────────────
    boot.kernel.sysctl = mkIf cfg.sysctls.enable {
      "vm.swappiness" = cfg.sysctls.swappiness;
      "vm.page-cluster" = cfg.sysctls.pageCluster;
      "vm.overcommit_memory" = if cfg.sysctls.strictOvercommit then 2 else 0;
    };
  };
}
