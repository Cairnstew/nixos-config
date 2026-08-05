# DECISION LOG — 2026-08-04 nix-refine

Date: 2026-08-04
Team: `refine-2026-08-04`

## Purpose

This is the DECISION LOG for all `lib.mkForce` sites in the repository. It exists
because `GOTCHAS.md:32-52,292` is the source of truth for mkForce sites but several
sites are documented only in code comments and no log row had ever been written.
Every mkForce in the tree must be traceable to exactly one row below (or to a new
row added with the change). **This document records existing state only — it implies
no code change.**

## Decision Log

### R1 — `modules/nixos/common.nix:205,225` — agenixManagerSecretsNix `.text`/`.deps`

`system.activationScripts.agenixManagerSecretsNix.text` (line 205) and
`.deps` (line 225) are set with `lib.mkForce` so that the activation script that
re-renders `/etc/agenix/secrets-manifest.json` always wins over any other module's
definition. The manifest is the single source of truth for agenix-manager secret
metadata (the CLI SSOT); a weaker-priority assignment would silently lose and the
manifest would be regenerated with wrong content.

**Secrets-critical — DO NOT touch.** Guard any override behind the same mkForce
and the same activation script.

### R2 — `modules/nixos/homeManager/config.nix:176-184` — agenix secret owner/group (13 sites)

Thirteen `age.secrets.*` entries force `owner` (and, where needed, `group`) so the
decrypted files at `/run/agenix/*` are owned by the target user instead of root.
The mkForce sites sit on lines 176, 177, 178, 179, 180 (owner+group), 181, 182
(owner+group), 183, 184 (owner+group) — 13 total. They are already one consolidated
block; do not scatter new owner/group overrides elsewhere.

### R3 — `configurations/nixos/desktop/default.nix:26-44` — VM-test cluster (9 sites)

Nine mkForce sites inside the VM-test branch of the desktop host config
(`lib.vm`-gated `my.*` overrides) on lines 26, 27, 28, 29, 30, 32, 33, 43, 44:

| Line | Option |
|------|--------|
| 26 | `my.profiles.workstation.enable` |
| 27 | `my.profiles.gaming.enable` |
| 28 | `my.profiles.gpu.mesa.enable` |
| 29 | `my.profiles.location.enable` |
| 30 | `my.profiles.desktop.choice` |
| 32 | `my.system.battery.enable` |
| 33 | `my.services.proxy.listenAddresses` |
| 43 | `services.greetd.settings.default_session.command` |
| 44 | `services.greetd.settings.default_session.user` |

These are test-only overrides that force a known-good minimal VM configuration.
Line 33 (`proxy.listenAddresses`) had no explanatory comment at the time of this
log — task T2 adds it.

### R4 — Remaining pre-existing sites (all GOTCHAS-documented)

- `modules/nixos/tailscale/config.nix:24` — `environment.etc."resolv.conf".source`
  forced to systemd-resolved stub.
- `modules/nixos/bluetooth.nix:37` — `CapabilityBoundingSet` on the bluetooth unit.
- `modules/nixos/ai/comfyui/config.nix:92,112,113` — `comfy-ui` unit `script`,
  `ProtectHome`, `PrivateMounts`.
- `modules/nixos/disko/config.nix:111,116` — `fileSystems."/"` and `fileSystems."/boot"`
  on existing-disk installs.
- `modules/nixos/zerotier/config.nix:24` — `Restart = "on-failure"` (only the
  `wantedBy` mkForce was removed; the Restart one must stay — see GOTCHAS.md:292).
- `modules/nixos/hyprland/display-manager/config.nix:35` — greetd disabled in the
  sddm branch (see GOTCHAS.md:52).
- `modules/home/core/agenix.nix:27` — launchd `activate-agenix` agent `KeepAlive`
  (see GOTCHAS.md:44-46).
- `modules/flake-parts/` — 8 sites: `packages.nix:23,24`,
  `test-runner.nix:15,16`, `vm/config.nix:44,45`, `live-iso/config.nix:87,102`.

All of these pre-date this log, are documented in GOTCHAS.md, and are untouched
by this run.

## Run Summary

- Recon on 2026-08-04 found 41 findings across the tree, triaged into 21 tasks.
- This run adds **no new mkForce sites** — it only logs the ones that already exist.
- Task T1 (this file) is documentation-only; no `.nix` file was modified.
