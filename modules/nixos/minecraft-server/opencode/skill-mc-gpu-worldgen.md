---
name: mc-gpu-worldgen
description: Use when investigating or re-enabling GPU-accelerated chunk/world generation for a minecraft-server pack in this repo (c2me-ocl + OpenCL), when debugging why OpenCL finds no platforms or hangs, or when RoadWeaver's OpenCL-coarse-sampling logs its CPU fallback. Documents the dormant GPU/OpenCL wiring left in place, the two failure modes already diagnosed, and the retry path.
---

# GPU-Accelerated Worldgen (c2me-ocl / OpenCL)

GPU worldgen on this repo's dedicated minecraft servers is currently **off by
design**: c2me-ocl was tried on AllTheTech, hit two hard walls (both diagnosed),
and was removed. The GPU/OpenCL *wiring* was deliberately left **dormant** in
the module so a retry is cheap once the blocker is gone. This skill records the
whole saga so a future session doesn't re-litigate it.

## Current state (2026-08-16)

- **c2me-ocl is NOT in the pack.** `mods/c2me-ocl.pw.toml` was deleted. Noisium
  was re-added in its place (it covers the noise-gen optimization c2me-ocl was
  replacing). Do not re-add c2me-ocl until the blocker below is gone.
- **The GPU/OpenCL wiring is dormant but present** and harmless when unused:
  - `modules/nixos/minecraft-server/config.nix` → `mkHardwareServiceConfig`
    injects `environment.LD_LIBRARY_PATH = /run/opengl-driver/lib` and relaxes
    the unit's device sandbox (`PrivateDevices = lib.mkForce false`,
    `DevicePolicy = "closed"`, `DeviceAllow` for `/dev/nvidia*`,
    `/dev/dri/card*`, `/dev/dri/renderD*`, `char-rtc`).
  - `modules/nixos/graphics/config.nix` → NVIDIA branch adds `pkgs.ocl-icd` to
    `hardware.graphics.extraPackages`.
  - `servers/allthetech.nix` jvmOpts still carries
    `-Dorg.lwjgl.opencl.libname=/run/opengl-driver/lib/libOpenCL.so.1`.
  - `config/c2me.toml` `[openclAccel]` keeps retry-doc values
    (`allowIncompatibilityFallback`, `enableNvidiaFastCompilation`,
    `preserveAllControlFlows`).
- **Server runs fine without it**: first boot `Done (107.467s)` on a fresh
  world, 0 restarts, ~4.5-4.8G RSS, Chunky pregen ~17 cps. Startup was tuned via
  RoadWeaver preload radii (see below), not via GPU.

## Failure mode 1: OpenCL finds no platforms (`CL_PLATFORM_NOT_FOUND_KHR`, -1001)

**Symptom:** c2me-ocl logs `failed to get an OpenCL platform` / `-1001` even
though `nvidia-smi` and `clinfo` (run on the host) both see the GPU.

**Root cause:** nix-minecraft hardens every generated unit with
`PrivateDevices = true` + `DevicePolicy = closed` + `DeviceAllow = [ "" ]`. That
mounts a **private `/dev` with NO `/dev/nvidia*` or `/dev/dri/*` nodes** inside
the unit. The OpenCL ICD loads fine but enumerates **zero platforms** because it
can never open a GPU node. A bare `clinfo` on the host works — the *unit* is the
problem, so testing outside the unit misleads.

**Fix (already applied, dormant):** in `mkHardwareServiceConfig`:
`PrivateDevices = lib.mkForce false` (share the host `/dev`), keep
`DevicePolicy = "closed"` but add `DeviceAllow` for the NVIDIA + DRM render
nodes. This is what makes `clinfo`/OpenCL see the GPU when c2me-ocl is present.

## Failure mode 2: the NVIDIA 595.80 OpenCL compiler hangs (`clBuildProgram`)

**Symptom:** with GPU access working, c2me-ocl's `clBuildProgram` (JNI) hangs
**indefinitely** on c2me's generated noise kernel. Observed as a 35+ min stall
with the Java thread making only ~110ms of CPU progress — i.e. not busy work,
it's blocked in the vendor compiler.

**Root cause:** a bug in the NVIDIA 595.80 OpenCL compiler with c2me's
heavily-unrolled generated kernel — **not** fixable from config or JVM flags.
Confirmed by thread dumps (`jstack`) showing the stall inside the native
`clBuildProgram` call.

**Fix:** abandon c2me-ocl on this driver. The wiring stays dormant so the next
attempt is one `packwiz modrinth add c2me-ocl` away once the driver is
fixed/upgraded (or the vendor compiler handles the kernel).

## Failure mode 3 (JVM trap): `-XX:+UseCompactObjectHeaders`

While chasing the hang, `-XX:+UseCompactObjectHeaders` was tried. It **breaks
JNI/FFI** (`java.lang.foreign`), which made the OpenCL path even more broken.
**Do not re-add it.** (Noted in `servers/allthetech.nix`.)

## Heap guidance for GPU worldgen

c2me-ocl's FAQ: ZGC is only worthwhile above ~16G heap; under that G1GC avoids
extra native memory. Current jvmOpts use `-Xmx6G -Xms3G -XX:+UseG1GC
-XX:G1HeapRegionSize=16M` — keep G1 unless the heap grows well past 16G.

## Retry checklist (when you want to attempt GPU worldgen again)

1. Confirm the NVIDIA driver is **newer than 595.80** (or otherwise known to not
   hang) — check `nvidia-smi` on the server host.
2. `packwiz modrinth add c2me-ocl` in the pack, regenerate checksums, rebuild.
3. Verify the unit can reach the GPU: `systemctl show minecraft-server-<name>`
   shows `PrivateDevices=no`; `systemd-run --service-type=oneshot` a `clinfo`
   in the unit's environment.
4. Boot and **watch closely**: if `clBuildProgram` stalls again (server thread
   blocked, ~0 CPU progress in `jstack`), remove c2me-ocl again and fall back to
   Noisium — don't chase config.
5. Never add `-XX:+UseCompactObjectHeaders`.

## RoadWeaver OpenCL / preload interplay

RoadWeaver (road generation) has its own OpenCL coarse-sampling, but it **falls
back to CPU** when base c2me's density-function nodes are present — it logs
benign lines like `OpenCL 粗采样暂不支持主世界，回退到 CPU: unsupported density
node: com.ishland.c2me.opts.df...`. Those are **not errors**.

With the CPU fallback active, RoadWeaver's `preloadBeforePrepareLevels` uses the
values in `config/roadweaver/roadweaver.json`, and huge radii are fatal on a
fresh world: `predictRadiusChunks 256` + `initialPlanRadiusChunks/dynamicPlan
128` spun ~4 CPU cores for **hours** after "Done" (looked like a hang). Tuned
values (AllTheTech): `predictRadiusChunks 32`, plan radii `16`, stride `64`,
`initialGenerationThreads 6`. Any future GPU enablement should re-check these
with OpenCL active — GPU coarse sampling changes the CPU cost profile.

## RUN LOG

### 2026-08-16 — first attempt: GPU worldgen for DragonTech, abandoned
Lesson: c2me-ocl went through three distinct failures in one session. (1) -1001:
nix-minecraft's `PrivateDevices=true` hides `/dev/nvidia*`/`/dev/dri/*` from the
unit, so OpenCL found zero platforms — fixed by `PrivateDevices=false` +
`DeviceAllow`. (2) With the GPU reachable, the NVIDIA 595.80 OpenCL compiler
hangs indefinitely (`clBuildProgram` JNI, ~110ms CPU progress over 35+ min) on
c2me's generated noise kernel — a vendor driver bug, not config-fixable. (3)
`-XX:+UseCompactObjectHeaders` broke JNI/FFI and was removed. Conclusion: remove
c2me-ocl, re-add Noisium, keep the OpenCL wiring dormant for a retry.
Fix: this skill created; `config.nix`/`graphics/config.nix`/`dragentech.nix`
comments already document the dormant wiring.
