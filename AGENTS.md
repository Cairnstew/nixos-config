# AGENTS.md — Top-Level Direction

> This is the root policy for the NixOS / nix-darwin configuration flake.
> Subdirectories may contain their own `AGENT.md` (singular) files with local rules.
> When they conflict, the **most specific** `AGENT.md` wins.

---

## Required Reading

Before doing anything in this repo, read these files in order:

1. `STRUCTURE.md` — annotated repo tree; tells you what every file does and what flake output it maps to
2. `HEATMAP.md` — exact files to read/edit for the 8 most common tasks, plus the full `my.*` Option Registry
3. `SECRETS.md` — agenix secrets: catalog, consumption, encryption, nixos-unified integration
4. `GOTCHAS.md` — known footguns and their fixes; check this before debugging any evaluation or build failure
5. `modules/AGENT.md` — universal module structure, `my.*` namespace, and per-module conventions
6. `configurations/AGENT.md` — host configuration conventions and profile usage
7. `modules/flake-parts/README.md` — flake-parts layer documentation: identity options, `perSystem` vs `flake.*` outputs
8. `modules/flake-parts/ventoy/README.md` — Ventoy multi-boot USB system: ISO build, deploy, answer files, debugging

When you discover a new problem and its solution, append an entry to `GOTCHAS.md` immediately.
When your session teaches you something about these guidance files themselves
(stale path, misleading rule, missing convention), apply it before you finish —
see §11 Self-Improvement.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Directory → Flake Output Map](#2-directory--flake-output-map-autowiring)
3. [Configuration Architecture](#3-configuration-architecture)
4. [Profiles System](#4-profiles-system)
5. [Module Conventions](#5-module-conventions)
6. [Configuration Conventions](#6-configuration-conventions)
7. [Secrets](#7-secrets)
8. [Common Tasks](#8-common-tasks)
9. [Style & Lint](#9-style--lint)
10. [Subdirectory Policies](#10-subdirectory-policies)
11. [Self-Improvement](#11-self-improvement)

---

## 1. Project Overview

This is a multi-system Nix configuration managed by one flake targeting:

* **NixOS** laptops, servers, WSL instances, and cloud VMs
* **nix-darwin** (macOS) — dormant but wired (`aarch64-darwin` is in the flake's
  systems list; no darwin host config exists yet)
* **Home Manager** standalone configurations

The two structural pillars are:

1. **`flake-parts`** — module system for the flake itself (`perSystem`, `flake.*` outputs).
2. **`nixos-unified`** — provides `flakeModules.autoWire` so files under
   `configurations/` and `modules/` are **automatically** exported as flake outputs
   without manual registration in `flake.nix`.

---

## 2. Directory → Flake Output Map (Autowiring)

| Path | Flake output |
|------|--------------|
| `configurations/nixos/(host-name).nix` or `…/(host-name)/default.nix` | `nixosConfigurations.(host-name)` |
| `configurations/darwin/(host-name).nix` or `…/(host-name)/default.nix` | `darwinConfigurations.(host-name)` *(dir not yet present — dormant)* |
| `configurations/home/(user-name).nix` | `homeConfigurations.(user-name)` *(dir not yet present)* |
| `modules/nixos/(name).nix` or `…/(name)/default.nix` | `nixosModules.(name)` |
| `modules/darwin/(name).nix` or `…/(name)/default.nix` | `darwinModules.(name)` *(dir not yet present — dormant)* |
| `modules/home/(name).nix` or `…/(name)/default.nix` | `homeModules.(name)` |
| `modules/flake-parts/(name).nix` | imported into `flake-parts` top-level |
| `modules/flake-parts/(name)/default.nix` | auto-imported from subdirectories (like autowiring) |
| `overlays/(name).nix` | `overlays.(name)` |
| `packages/(name)/` or `packages/(name).nix` | auto-wired via `perSystem` |
| `modules/nixos/secrets/` | agenix secrets (not a flake output) |

**Agent rule:** If you add a new file in one of the autowired directories it
*will* become a flake output automatically. Do not duplicate imports in
`flake.nix`.

---

## 3. Configuration Architecture

### 3.1 Quick Start

Create a new NixOS host:

```bash
mkdir configurations/nixos/myhost
cat > configurations/nixos/myhost/default.nix
```

```nix
{ flake, ... }:
{
  imports = [ flake.inputs.self.nixosModules.common ];
  
  networking.hostName = "myhost";
  nixpkgs.hostPlatform = "x86_64-linux";
  
  # Pick profiles
  my.profiles.workstation.enable = true;
  my.profiles.desktop.gnome.enable = true;
  my.homeProfiles.common.enable = true;
  my.homeProfiles.desktop.enable = true;
}
```

### 3.2 Architecture Overview

```
configurations/nixos/           # Host configurations
├── desktop/                    # Desktop PC (AMD, dual-boot Windows)
│   ├── configuration.nix
│   ├── default.nix             # Host configuration (imports common)
│   ├── disk-config.nix         # Disko partitioning
│   └── hardware-configuration.nix  # Generated hardware config
├── laptop/                     # Laptop with GUI
│   ├── default.nix             # Host configuration (imports common)
│   ├── disk-config.nix         # Disko partitioning
│   └── hardware-configuration.nix  # Generated hardware config
├── minimal/                    # Minimal host
│   ├── configuration.nix
│   ├── default.nix
│   ├── disk-config.nix
│   └── hardware-configuration.nix
├── server/                     # Headless server
│   ├── configuration.nix
│   ├── default.nix
│   ├── disk-config.nix
│   └── hardware-configuration.nix
└── wsl/                        # WSL instance
    ├── configuration.nix
    └── default.nix

modules/nixos/                 # NixOS modules
├── common.nix                  # Common configuration (import this!)
├── profiles/                  # System & home profiles
│   ├── system/                # System-level profiles
│   │   ├── workstation.nix
│   │   ├── server.nix
│   │   ├── development.nix
│   │   ├── minimal.nix
│   │   └── ...                # gaming, media, entertainment, ai
│   └── home/                  # Home-level profiles
│       ├── default.nix
│       ├── common.nix
│       ├── desktop.nix
│       └── ...
└── ...                        # Individual modules
```

### 3.3 Key Principles

1. **Import `nixosModules.common`** — This single import provides all base functionality
2. **Use Profiles** — Enable features via `my.profiles.*` and `my.homeProfiles.*`
3. **Minimal Boilerplate** — Host configs should be declarative and short
4. **No Direct Module Imports** — Don't import individual modules in host configs

---

## 4. Profiles System

Profiles provide convenient bundles of related configuration.

### 4.1 System Profiles (`my.profiles`)

| Profile | Purpose | Enables |
|---------|---------|---------|
| `workstation` | Desktop/laptop | Audio, bluetooth, desktop environment |
| `server` | Headless server | SSH, minimal services |
| `minimal` | Bare essentials | Core services only |
| `development` | Dev tools | Docker, git, direnv |
| `gaming` | Gaming setup | Steam, gaming tools |
| `media` | Media stack | Prowlarr, Sonarr, Radarr, Jellyfin |
| `entertainment` | Entertainment | Gaming, music, media services |
| `ai` | AI frontends | RisuAI, Open WebUI, Letta, Jan |

**Feature Profiles:**

| Profile | Purpose |
|---------|---------|
| `desktop.gnome` | GNOME desktop |
| `desktop.hyprland` | Hyprland Wayland compositor |
| `desktop.choice` | Desktop-environment selection (hyprland/gnome) |
| `gpu.mesa` | Intel/AMD graphics |
| `gpu.nvidia` | NVIDIA graphics |
| `gpu.nvidia-headless` | NVIDIA (headless/CUDA) |
| `battery` | Power management |
| `location` | Timezone/geolocation |
| `power.desktop` | Desktop power profile (never sleep, no lock) |
| `power.laptop` | Laptop power profile (battery-aware, lock on idle) |
| `testing` | Module smoke tests and health checks |
| `theming.stylix` | Stylix theming framework |

**Example:**

```nix
my.profiles = {
  workstation.enable = true;
  development.enable = true;
  desktop.gnome.enable = true;
  gpu.mesa.enable = true;
  battery.enable = true;
};
```

### 4.2 Home Profiles (`my.homeProfiles`)

| Profile | Purpose | Programs |
|---------|---------|----------|
| `common` | Basic shell tools | bash, zsh, direnv, gh, ghostty, just, yazi |
| `desktop` | GUI applications | firefox, discord, obsidian |
| `development` | Dev tools | vscode, cudatext |
| `server` | Server user | minimal GUI |
| `minimal` | Essential only | bash only |

**Example:**

```nix
my.homeProfiles = {
  common.enable = true;
  desktop.enable = true;
  development.enable = true;
};
```

### 4.3 Per-Host Customization

For host-specific home settings:

```nix
my.homeManager.extraConfig.my.programs = {
  steam.enable = true;  # Extra program for this host
  firefox.enable = false; # Disable default
};
```

---

## 5. Module Conventions

### 5.1 All Modules

* All custom options MUST live under the `my.*` namespace
* Module file names match the option path: `my.services.tailscale` → `modules/nixos/tailscale/`
* Directories are used for complex modules: `modules/nixos/tailscale/`

### 5.2 Module Structure

```
modules/nixos/example/
├── default.nix      # Entrypoint (imports only)
├── meta.nix         # Machine-readable metadata (pure attrset)
├── options.nix      # Option declarations
├── config.nix       # Main implementation
├── services.nix     # systemd units
├── tests.nix        # Tests & assertions
└── README.md        # Human documentation
```

**Rule:** `default.nix` is an **import manifest** — contains only `imports`, no logic.

See `modules/AGENT.md` for detailed module conventions.

---

## 6. Configuration Conventions

### 6.1 Configuration Structure

**Good:**
```nix
{ flake, ... }:
{
  imports = [ flake.inputs.self.nixosModules.common ];
  
  networking.hostName = "laptop";
  nixpkgs.hostPlatform = "x86_64-linux";
  
  my.profiles.workstation.enable = true;
  my.profiles.desktop.gnome.enable = true;
  my.homeProfiles.common.enable = true;
}
```

**Avoid:**
```nix
{ config, flake, pkgs, lib, ... }:
let
  me = flake.config.me;
  user = me.username;
  self = flake.inputs.self;
in
{
  imports = [
    ./configuration.nix
    self.nixosModules.default
  ];
  # ... verbose config with many let bindings
}
```

### 6.2 Required Settings

Every configuration MUST set:

1. `networking.hostName` — The hostname
2. `nixpkgs.hostPlatform` — System architecture (e.g., "x86_64-linux")
3. Import `nixosModules.common` — Base configuration

### 6.3 Override Specifics, Not Defaults

Set specific values only when needed:

```nix
# Good: Override specific setting
my.services.tailscale.tags = [ "tag:laptop" "tag:mobile" ];

# Avoid: Re-declaring defaults
my.services.tailscale = {
  enable = true;  # Already default in common.nix
  user = "seanc"; # Already default
};
```

### 6.4 Secrets Handling

Don't reference secrets directly. Use conditional guards:

```nix
# Good: Check if secret exists first
my.caches.personal.push.enable = config.age.secrets ? "nixos-config-cache-token";

# Bad: Will fail if secret missing
my.caches.personal.push.tokenFile = config.age.secrets."nixos-config-cache-token".path;
```

---

## 7. Secrets

Secrets are managed with **agenix-manager**. See `SECRETS.md` for the full reference.

* Encryption rules: `modules/nixos/secrets/secrets-manifest.json` — declares each
  secret's name, scope, owner, group, and mode
* Encrypted blobs: `modules/nixos/secrets/<name>.age` (flat, no subdirectories)
* Catalog: `modules/nixos/secrets/` — the manifest is the SSOT; key groups are
  defined in `modules/nixos/common.nix` under `agenixManager.keys.groups.*`
* Decryption: At activation time via SSH host keys → `/run/agenix/<name>`

**Key patterns:**
```nix
config.age.secrets."<name>".path   # → /run/agenix/<name>
config.age.secrets ? "<name>"      # existence guard (use this!)
```

**Agent rule:** Never commit plaintext secrets. Always guard secret access with
the `?` existence check. Note: CI package builds (`modules/flake-parts/packages.nix`)
do not currently disable agenix-manager — the committed `.age` files evaluate fine —
but the guard pattern is still required for any secret that may not exist on every host.

---

## 8. Common Tasks

| Task | Command |
|------|---------|
| Activate current host | `nix run` |
| Update all flake inputs | `nix flake update` or `nix run .#update` |
| Update specific inputs | `nix flake lock --update-input nixpkgs --update-input home-manager` |
| Format the tree | `nix fmt` |
| Build a host (CI) | `nix build .#<host>` (ci.yml matrix: laptop/server/wsl) |
| Check flake | `nix flake check --no-build` |
| Deploy a host | `just deploy-run <host> <target>` (or `nix run .#deploy-<host> -- <target>`) |
| Run nixtest suites | `nix run .#nixtests-run` |
| Garbage collect | `sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +2 && sudo nixos-rebuild boot` |

---

## 9. Style & Lint

* Use `nixpkgs-fmt` (enforced by `nix fmt`).
* Prefer `lib.mkDefault` in common modules so host configs can override easily.
* Use `lib.mkOption` + `lib.mkEnableOption` for all new `my.*` options.
* Keep `let … in` blocks close to where they are used; avoid giant top-level
  `let` bindings in host configs.

---

## 10. Subdirectory Policies

The following subdirectories carry their own `AGENT.md` (or equivalent)
policy docs. When they conflict, the **most specific** `AGENT.md` wins.

* **`modules/AGENT.md`** — universal module structure, `my.*` namespace,
  `meta.nix`, `tests.nix`, and per-type directives (NixOS, darwin, home,
  flake-parts).
* **`configurations/AGENT.md`** — host configuration conventions, profiles
  usage, and examples.
* **`modules/flake-parts/README.md`** — flake-parts layer documentation:
  identity options, `perSystem` vs `flake.*` outputs, and conventions for
  adding new flake-level modules.

---

## 11. Self-Improvement

The `nix-refine` and `nix-doc-audit` commands improve themselves after each run
(Phase 6 + RUN LOG). The guidance files follow the same discipline: **each session
leaves the guidance better than it found it.** This section is the protocol; the
sub `AGENT.md` files (`modules/AGENT.md`, `configurations/AGENT.md`,
`modules/home/opencode/AGENT.md`) each carry a pointer and their own RUN LOG.

### 11.1 When

At the end of your task, before reporting done, take a short pass over the
guidance file(s) you relied on this session.

### 11.2 What to fix

- **Misleading guidance** — an instruction you followed that wasted effort or led
  you astray this session. Fix the instruction, don't just work around it.
- **Stale facts** — paths, `my.*` option names, profile/host names, or commands
  that no longer match the repo.
- **Missing guidance** — a pattern, trap, or convention you had to discover the
  hard way and the next agent would also need.
- **Contradictions** — two rules that conflict; reconcile them in-place.

### 11.3 Grounding discipline (mirrors the commands' Phase 6)

- Every edit must be grounded in something that **actually happened this session**
  (cite `file:line`) or **exists in the repo now**. Never add aspirational or
  speculative guidance ("in future we might…").
- Keep edits tight and in-place — improve the section the rule lives in; don't
  append a parallel version of it.
- Behavioural problems/solutions belong in `GOTCHAS.md` (see Required Reading);
  this section is for guidance-file fixes only.
- Do not let the file balloon. Fix what is true now; leave the rest for a real
  event.

### 11.4 Self-improvement is a single in-band checkpoint

Self-improvement is now a **single, in-band, per-response checkpoint** run by the
checkpoint-carrying primary agents (`build`, `researcher`) — there is no separate
review/promotion pipeline, no queue, and no `learning_*` tools anymore (the goals
MCP no longer exposes them).

- **How it works:** after every response/task (when `SELF_IMPROVE=true`, the
  current default in `agents/build.md`) the agent runs a short, cheap, structured
  self-check: capture grounded run lessons, audit the guidance it relied on, then
  either apply an **append-only, evidence-backed** edit to an **allow-listed**
  target as its **own commit**, or explicitly state "no lessons this run". A
  runtime guard plugin (`self-improve-guard`) reminds the session if it skipped
  the checkpoint.
- **Mechanical guards (non-LLM), not reviewers:** the commit-helper
  (`tools/self-improve-commit.sh`) every self-apply must go through instead of raw
  `git commit` enforces: (1) the cited `file:line` exists at write time, (2) the
  target is on the Decision-2 allow-list (GOTCHAS.md,
  `modules/home/opencode/{skills,commands}/*.md` RUN LOG sections, module
  `AGENT.md` RUN LOG sections) and off the hard deny-list (`secrets/`, `proxy/`,
  `disko/`, any `network*` module, `config.nix`, `options.nix`), (3) the diff is
  pure insertion, and (4) the Decision-3 rate caps
  (`my.programs.opencode.selfImprove.maxCommitsPerSession`/`maxCommitsPerDay`,
  default `null` = uncapped). On any failure it leaves the edit unstaged and
  reports why.
- **Audit trail:** each self-apply is its **own** commit with a `Self-Improve:`
  trailer — `git log --grep="Self-Improve:"` is the audit trail; `git revert` is
  the rollback net. The repo stays manual-push.
- **Un-gated channels:** behavioural problems/solutions still go straight into
  `GOTCHAS.md` (§11.3), and the Minecraft pack/packwiz tooling keeps its own
  direct RUN LOG convention (below).
- **Two lenses, one checkpoint — no second pipeline.** The single in-band pass
  carries two lenses. The **correctness lens** is the mechanical/self-applying one
  described above (allow-listed commit-helper self-applies). The **efficiency
  lens** is proposal-only: the same pass also queries the session's own
  `opencode.db` row (`cost` / `tokens_input/output/reasoning/cache_read/cache_write`)
  and `part`-table tool-call count (reusing `self-improve-guard.ts`'s bun:sqlite
  pattern), and when a genuinely repeated pattern would be collapsed by a new
  tool/skill/command/config, writes a **proposal** (name + quantitative evidence,
  marked proposal-only, never built this session) to the repo-root
  `EFFICIENCY-PROPOSALS.md`. It is still the same checkpoint: one pass, both
  lenses, no new agent or gate. `EFFICIENCY-PROPOSALS.md` is allow-listed for the
  commit-helper (same evidence/append-only checks; evidence = DB query output).
  The optional threshold options
  `selfImprove.efficiencyLensMinToolCalls`/`...MinCost` (nullable, default `null`)
  can gate the lens later from usage data; unset, it runs every pass.

**Scoped exception — Minecraft pack/packwiz tooling (`modules/nixos/minecraft-server/opencode/`).**
This directory keeps its own direct RUN LOG self-improvement convention: editing the repo
tool/skill files there and appending dated Lesson/Fix RUN LOG entries (programmatically via
each tool's `note=` argument, or by hand) is permitted and expected after every packwiz/pack
session — do NOT route those lessons through the in-band checkpoint. This scoped exception
exists because Minecraft pack development self-improves its own tooling frequently and inline
(see the mc-modpack skill's "Self-improvement — mandatory end-of-session checkpoint").
Everything outside that directory relies on the in-band checkpoint above.

---

## Summary

**For Agents:**

1. Host configs should be **minimal** and **declarative**
2. Use **profiles** (`my.profiles.*`, `my.homeProfiles.*`) for common patterns
3. Import **`nixosModules.common`** for base functionality
4. Set `networking.hostName` and `nixpkgs.hostPlatform`
5. Follow the **AGENT.md** hierarchy for detailed conventions
6. Improve these guidance docs at the end of your session (§11 Self-Improvement)

---

## RUN LOG

### 2026-09-05 — goals MCP appears unwired on desktop; SUPERSEDED 2026-09-12 by full pipeline decommission
- Lesson: sessions ran where `learning_append` (goals MCP) was not available and
  stranded grounded lessons in chat. Root-caused at the time as "the goals MCP
  server is not registered anywhere — `config.nix` wires only `nix-graph`
  (line 346)". **Correction (2026-09-12, Tier 0 re-check):** the goals MCP IS
  wired on `server` via `modules/home/goals/config.nix` (it asserts
  `my.programs.opencode.mcp.goals`) once `my.programs.goals.enable = true`
  (`configurations/nixos/server/default.nix:53`); it is only absent on hosts
  (like `desktop`) where the goals module isn't enabled — the original
  root-cause claim ("not registered anywhere") conflated the goals-module wiring
  path with opencode's own `config.nix`.
- Fix: **superseded entirely by the 2026-09-12 decommission** of the gated
  triage+promote pipeline (single in-band SELF_IMPROVE checkpoint; audit via git
  log `Self-Improve:` trailer + GOTCHAS/RUN LOG). There are no `learning_*` tools
  and no promoter queue to reach anymore. The `packwiz.nix` `mkChecksumsApp` CWD
  bug fixed in the same session remains a durable fix (absolute `${modpacksDir}/<name>/checksums.json`).

### 2026-09-05 — scoped exception: minecraft pack/packwiz tooling self-improves directly
- Lesson: the RUN LOG convention in `modules/nixos/minecraft-server/opencode/`
  (edit the repo `.ts`/skill + `note=`) predates the §11.4 gating mandate, but
  was being treated as optional — sessions punted lessons to the review queue or
  logged junk ("init"), the marker-append code stacked duplicate `// ## RUN LOG`
  headers in the tool files, and `packwiz-checksums` had no self-improvement
  wiring at all (silently omitting untracked mods from checksums.json).
- Fix: made the checkpoint mandatory in the mc-modpack skill + command, deduped
  the `// ## RUN LOG` marker in every tool's `appendRunLog`, gave
  `packwiz-checksums` a `note=` param plus an automatic untracked-mods guard
  (blocks loudly, self-documents the lesson once), and added this scoped
  exception — everything under `modules/nixos/minecraft-server/opencode/`
  self-improves directly and must NOT be routed through
  `learning_append`/`learning_promote`.

### 2026-08-16 — §11.4: promote is no longer human-only
- Lesson: §11.4 said `learning_promote` "is for Sean or a human-reviewed session,
  never for the agent to call on itself mid-run", but the server guard is
  config-level and the repo has no human-only enforcement — and full-auto
  promotion was the requested direction.
- Fix: added the dedicated `learning-promoter` agent
  (`modules/home/opencode/agents/learning-promoter.md`) as the sole promote-
  capable agent, running headlessly/detached and only on a unanimous harness-
  re-derived triage `agree`, each apply as an isolated commit on its own branch.
  Updated §11.4, `modules/AGENT.md` §13, and all agent/command/skill docs that
  claimed a human was required.

### 2026-08-05 — added self-improvement protocol to the guidance files
- Lesson: `nix-refine` and `nix-doc-audit` improve their own command files after
  each run, but the AGENTS guidance files had no equivalent — so doc drift (stale
  paths, rules that misled sessions) could only be fixed by the manual
  `nix-doc-audit` pass.
- Fix: added §11 Self-Improvement and this RUN LOG. Added matching pointer
  sections + RUN LOGs to `modules/AGENT.md`, `configurations/AGENT.md`, and
  `modules/home/opencode/AGENT.md`.
