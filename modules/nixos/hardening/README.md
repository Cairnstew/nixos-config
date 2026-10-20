# Hardening

Memory/CPU pressure hardening so machines stay reachable via SSH even under
extreme load. Layered defense:

1. **zram** — compressed swap as a reclaim valve before the box freezes.
2. **earlyoom** — fast, global; kills the largest offender when available
   RAM/swap drops below a threshold (catches fast allocations before PSI builds).
3. **systemd-oomd** — cgroup-aware pressure killing at 60% PSI for 30s.
4. **workload cgroup caps** — `user.slice` and `nix-daemon` cannot consume all
   RAM; the runaway `nix` hits its own cgroup OOM killer instead of the host.
5. **protected units** — sshd/tailscaled are excluded from both kernel and oomd
   kill selection.
6. **out-of-band recovery** — hardware watchdog reboot + Magic SysRq over
   PiKVM/IPMI when everything else fails.

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
| `my.system.hardening.oomd.defaultMemoryPressureLimit` | `60%` | Kill under sustained memory pressure (applied to `user.slice`/`system.slice`) |
| `my.system.hardening.oomd.defaultMemoryPressureDurationSec` | `30s` | Pressure duration before oomd acts (`...DurationSec`, not `...DurationUSec`) |
| `my.system.hardening.earlyoom.enable` | `true` | Fast global OOM backstop |
| `my.system.hardening.earlyoom.freeMemThreshold` | `10` | SIGTERM below this % of available RAM |
| `my.system.hardening.earlyoom.freeSwapThreshold` | `10` | SIGTERM below this % of free swap |
| `my.system.hardening.earlyoom.avoid` | sshd/tailscaled/systemd regexes | Processes earlyoom must never kill |
| `my.system.hardening.earlyoom.prefer` | nix/node/java/compiler regexes | Processes earlyoom should kill first |
| `my.system.hardening.workloadLimits.enable` | `true` | Cap user sessions + nix builds |
| `my.system.hardening.workloadLimits.userSliceMemoryHigh` | `60%` | Throttle point for `user.slice` |
| `my.system.hardening.workloadLimits.userSliceMemoryMax` | `65%` | Hard cap for `user.slice` |
| `my.system.hardening.workloadLimits.nixDaemonMemoryHigh` | `35%` | Throttle point for `nix-daemon` |
| `my.system.hardening.workloadLimits.nixDaemonMemoryMax` | `45%` | Hard cap for `nix-daemon` |
| `my.system.hardening.workloadLimits.systemSliceMemoryMin` | `10%` | Reclaim floor reserved for `system.slice` |
| `my.system.hardening.magicSysRq.enable` | `true` | `kernel.sysrq=1` (Alt+SysRq+F/B via PiKVM) |
| `my.system.hardening.watchdog.runtimeSec` | `null` | Hardware watchdog timeout; set e.g. `"60s"` on remote hosts |
| `my.system.hardening.protectedUnits` | `["sshd" "tailscaled"]` | Units with OOMScoreAdjust=-1000, ManagedOOMPreference=omit, CPUWeight=1000 |
| `my.system.hardening.cpuQuota` | see below | CPUQuota per heavy service |
| `my.system.hardening.sysctls.swappiness` | `100` | vm.swappiness |
| `my.system.hardening.sysctls.pageCluster` | `0` | vm.page-cluster |
| `my.system.hardening.sysctls.strictOvercommit` | `false` | vm.overcommit_memory=2 (risky) |

Default `cpuQuota`: `docker-ollama`/`podman-ollama`/`comfy-ui` = `400%`,
`jellyfin` = `300%`. Tune to the box's core count, leaving ~1 core headroom.

## Usage

Wired into `modules/nixos/common.nix` so all hosts get it by default. A remote
server should additionally enable the hardware watchdog:

```nix
my.system.hardening = {
  enable = true;
  watchdog.runtimeSec = "60s";   # reboot a livelocked box instead of leaving it unreachable
  magicSysRq.enable = true;      # Alt+SysRq+F / B from the PiKVM
  cpuQuota = {
    "docker-ollama" = "600%";    # 8-core box → leave 2 cores
  };
  protectedUnits = [ "sshd" "tailscaled" "ttyd" ];  # no .service suffix
};
```

## Notes

- **`protectedUnits` names must not carry `.service`.** The module merges them
  into `systemd.services.<name>`; passing `"sshd.service"` creates a bogus
  `sshd.service.service` unit and leaves the real `sshd` at `OOMScoreAdjust=0`.
  A suffix is accepted and stripped for backwards compatibility, and
  `tests.nix` asserts the effective unit config to catch a regression.
- **oomd's key is `DefaultMemoryPressureDurationSec`.** The former
  `...DurationUSec` spelling is not a systemd-oomd option; the journal logs
  `Unknown key ... ignoring` and the built-in 20s applies.
- **NixOS sets `ManagedOOMMemoryPressureLimit=80%`** on `user.slice` and
  `system.slice`, which overrides `oomd.conf`'s default. The module sets the
  configured `defaultMemoryPressureLimit` on both slices explicitly.
- **Why both earlyoom and oomd?** oomd reacts to PSI pressure, which can lag a
  fast allocator (the 2026-10-19 incident had a `nix` process at 10.5 GB anon-RSS
  that triggered the kernel OOM killer before oomd acted). earlyoom watches
  MemAvailable/SwapFree and kills sooner. oomd remains useful for cgroup-scoped
  pressure.
- **Why cap `user.slice`?** A raw `nix flake check` from a terminal runs in the
  user session cgroup. The `systemd-run` wrapper in the opencode tools only
  covers one code path; the slice cap covers every raw invocation. The web
  service is already capped separately (`opencodeWeb.memoryMax`, default 8G).
  The `nix-eval` and `nix-flake-check` opencode tools also run their evaluation
  under `systemd-run --user --scope -p MemoryMax=… -p MemorySwapMax=0`, and the
  opencode-web unit exports the user-bus environment (`XDG_RUNTIME_DIR`,
  `DBUS_SESSION_BUS_ADDRESS`) so that wrapper also works from a browser session.
- `strictOvercommit` is off by default; it can break apps relying on
  overcommit. zram + earlyoom + oomd is the safer path.
