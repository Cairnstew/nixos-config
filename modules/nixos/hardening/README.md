# Hardening

Memory/CPU pressure hardening so machines stay reachable via SSH even under
extreme load: compressed zram swap as a reclaim valve, systemd-oomd proactive
OOM killing, OOM-protected SSH-critical services, and CPU quotas on
memory/CPU-hungry services.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.system.hardening.enable` | `false` | Enable hardening |
| `my.system.hardening.zram.enable` | `true` | zram compressed swap |
| `my.system.hardening.zram.memoryPercent` | `50` | Max zram size as % of RAM |
| `my.system.hardening.zram.algorithm` | `zstd` | Compression algorithm |
| `my.system.hardening.zram.priority` | `100` | Swap priority |
| `my.system.hardening.oomd.enable` | `true` | systemd-oomd on root/system/user slices |
| `my.system.hardening.oomd.swapUsedLimit` | `90%` | Kill when swap usage exceeds this |
| `my.system.hardening.oomd.defaultMemoryPressureLimit` | `60%` | Kill under sustained memory pressure |
| `my.system.hardening.protectedUnits` | `["sshd.service" "tailscaled.service"]` | Units with OOMScoreAdjust=-1000, CPUWeight=1000 |
| `my.system.hardening.cpuQuota` | see below | CPUQuota per heavy service |
| `my.system.hardening.sysctls.swappiness` | `100` | vm.swappiness |
| `my.system.hardening.sysctls.pageCluster` | `0` | vm.page-cluster |
| `my.system.hardening.sysctls.strictOvercommit` | `false` | vm.overcommit_memory=2 (risky) |

Default `cpuQuota`: `docker-ollama`/`podman-ollama`/`comfy-ui` = `400%`,
`jellyfin` = `300%`. Tune to the box's core count, leaving ~1 core headroom.

## Usage

Wired into `modules/nixos/common.nix` so all hosts get it by default:

```nix
my.system.hardening = {
  enable = true;
  cpuQuota = {
    "docker-ollama" = "600%"; # 8-core box → leave 2 cores
  };
  protectedUnits = [ "sshd.service" "tailscaled.service" "ttyd.service" ];
};
```

## Notes

- zram gives oomd/kernel a compressed reclaim target — RAM exhaustion degrades
  gracefully instead of freezing before anything gets killed.
- `protectedUnits` get `OOMScoreAdjust = -1000` (never the OOM victim) and
  `CPUWeight = 1000` (max scheduling priority) so remote access survives.
- `cpuQuota` caps heavyweight services so a runaway LLM/AI job can't starve
  SSH of CPU time. Entries for units that don't exist on a host are inert.
- `strictOvercommit` is off by default; it can break apps relying on
  overcommit (e.g. some databases). zram + oomd is the safer path.
