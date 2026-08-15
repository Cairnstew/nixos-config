---
name: mc-server-monitor
description: Use when monitoring a dedicated Minecraft server's performance — memory, CPU, TPS/overload warnings, players, disk, and host-level pressure — or when deciding how to cap a server's resources (the hardware option). Works for any server defined under modules/nixos/minecraft-server/servers/, no monitoring mod required.
---

# Minecraft Server Performance Monitoring

The DragonTech NeoForge server runs as a systemd unit
(`minecraft-server-<name>.service`) on the server host. Its resource use and
health are observable WITHOUT any client-side monitoring mod (spark etc.) — the
signals come from three places:

1. **systemd cgroup** — live memory / CPU usage and the caps set by the
   server's `hardware` option (`systemctl show minecraft-server-<name>`).
2. **the server log** — `logs/latest.log` carries NeoForge's tick-lag warnings
   (`Can't keep up! Is the server overloaded? Running Nms or N ticks behind`),
   which are the TPS proxy, plus join/leave lines.
3. **the dashboard management API** (`minecraft-dashboard-api`, loopback) —
   structured state + player count, proxied at `/api/minecraft/` on the
   dashboard, or direct `http://127.0.0.1:7799/`.

## Primary tool

Use **`mc-server <name> perf`** for a one-shot performance snapshot:

```
mc-server dragentech perf
# memory: 5.5G used / 10G cap
# cpu: 200% quota of 8 cores
# overload (last 2): 313 ticks behind (15.7s); 53 ticks behind (2.7s)
# recent joins: seanc
# players: 3
# host: 15G total, 11G used, 4G avail | swap: 7.8G total, 5G used
```

`mc-server <name> status` adds boot progress and uptime. For a live repeating
view, poll `perf` every few seconds or watch the Grafana dashboard
(`/grafana`, backed by node-exporter + Prometheus) for host-level trends.

## What the numbers mean

- **Memory**: the JVM heap (`-Xmx`) is the floor; the Java process also uses
  off-heap + metaspace, so RSS is usually 0.5–1G above `-Xmx`. NeoForge with
  200+ mods is genuinely hungry: expect 5–6G RSS at rest, more during chunk
  generation. `memoryHigh` throttles (reclaim) above the soft target;
  `memoryMax` is the hard OOM cap.
- **TPS / "Can't keep up"**: NeoForge logs this only when the server thread
  falls behind (53 ticks ≈ 1s, 313 ticks ≈ 6.3s). Zero warnings = healthy 20
  TPS. Repeated/frequent warnings = the server thread is saturated — the usual
  culprits on a modded pack are first-boot chunk generation (transient), heavy
  redstone/entities, or a data pack scanning huge regions (RoadWeaver's
  `predictRadiusChunks` was the DragonTech case).
- **CPU quota** (`hardware.cpuQuota`): only useful if set; without it the server
  can use all cores during generation. A `100%` quota = one core, `200%` = two.
- **Swap**: watch `host:` line. If swap climbs while the server idles, either
  the heap is too big for the box or something else on the host is under
  memory pressure. `memorySwapMax` caps the server's own swap use.

## Deciding / tuning the `hardware` option

Per-server resource caps live in the server definition
(`modules/nixos/minecraft-server/servers/<name>.nix`):

```nix
hardware = {
  memoryHigh = "7G";     # soft throttle target (reclaim above this)
  memoryMax = "10G";     # hard OOM cap
  memorySwapMax = "2G";  # cap this unit's swap use
  cpuQuota = "200%";     # cap CPU (null = unlimited)
  nice = 5;              # slightly lower scheduling priority
  ioWeight = 500;        # deprioritise disk I/O (1-10000, default 100)
};
```

Wired into `systemd.services.minecraft-server-<name>.serviceConfig`. Sizing
rule of thumb for a host with `N` GiB RAM:
`memoryMax ≈ min(N - 4, -Xmx + 2G)`, `memoryHigh ≈ memoryMax - 2G`. Keep ≥ 4G
headroom for the OS + other services (this host also runs opencode-web, backup,
monitoring, containers). After changing, rebuild + `mc-server <name> restart`,
then `mc-server <name> perf` to confirm the cgroup caps took effect.

## GOTCHAS / notes

- `MemoryMax`/`MemoryHigh` are **cgroup v2** limits; the JVM still needs a
  sensible `-Xmx` — the caps are a safety net, not a substitute for sizing the
  heap.
- Setting `memoryMax` too low (below steady-state RSS) OOM-kills the server
  (Result: memory / systemd kills the unit). Raise it, don't chase the JVM.
- `mc-server perf` reads the **running** unit; the log overload lines are
  cumulative since last start. For a fresh signal, note the count before a
  `restart` and compare after.
- The dashboard Minecraft section shows live state + players + Start/Stop/
  Restart; `perf` is the deeper resource view. Prometheus/Grafana
  (`my.services.monitoring`) covers the whole host (node-exporter on :9100).

## RUN LOG

### 2026-08-15 — first dedicated-server perf session
Lesson: DragonTech first boot logged `Can't keep up! ... 313 ticks behind` during
worldgen — transient saturation, not a fault; second boot was clean at ~85s. The
host is tight (15G RAM, 5G swap used) while the server RSS sat ~5.5G against
`-Xmx6G`, so the heap was nudged to `-Xmx5G -Xms3G` and `hardware` caps
(memoryHigh 7G / memoryMax 10G / memorySwapMax 2G / nice 5) were added via a new
per-server `hardware` option wired into the systemd unit. Added `mc-server perf`
to surface memory/CPU/TPS/overload/players without requiring spark.
Fix: new `hardware` submodule in `options.nix` + `mkHardwareServiceConfig` in
`config.nix`; `perf` action in `mc-server.ts`; this skill documents the workflow.
