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

---

## 1. Project Overview

This is a multi-system Nix configuration managed by one flake targeting:

* **NixOS** laptops, servers, WSL instances, and cloud VMs
* **nix-darwin** (macOS) — currently dormant but wired
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
| `configurations/darwin/(host-name).nix` or `…/(host-name)/default.nix` | `darwinConfigurations.(host-name)` |
| `configurations/home/(user-name).nix` | `homeConfigurations.(user-name)` |
| `modules/nixos/(name).nix` or `…/(name)/default.nix` | `nixosModules.(name)` |
| `modules/darwin/(name).nix` or `…/(name)/default.nix` | `darwinModules.(name)` |
| `modules/home/(name).nix` or `…/(name)/default.nix` | `homeModules.(name)` |
| `modules/flake-parts/(name).nix` | imported into `flake-parts` top-level |
| `modules/flake-parts/(name)/default.nix` | auto-imported from subdirectories (like autowiring) |
| `overlays/(name).nix` | `overlays.(name)` |
| `packages/(name)/` or `packages/(name).nix` | auto-wired via `perSystem` |
| `secrets/` | agenix secrets (not a flake output) |

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
├── laptop/                    # Laptop with GUI
│   ├── default.nix             # Host configuration (imports common)
│   └── hardware-configuration.nix  # Generated hardware config
├── server/                    # Headless server
│   └── default.nix
└── wsl/                       # WSL instance
    └── default.nix

modules/nixos/                 # NixOS modules
├── common.nix                  # Common configuration (import this!)
├── profiles/                  # System & home profiles
│   ├── system/                # System-level profiles
│   │   ├── workstation.nix
│   │   ├── server.nix
│   │   ├── development.nix
│   │   └── minimal.nix
│   └── home/                  # Home-level profiles
│       ├── default.nix
│       ├── common.nix
│       └── desktop.nix
└── ...                        # Individual modules

modules/home/                  # Home Manager modules
└── ...                        # Individual program modules
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

**Feature Profiles:**

| Profile | Purpose |
|---------|---------|
| `desktop.gnome` | GNOME desktop |

| `gpu.mesa` | Intel/AMD graphics |
| `gpu.nvidia` | NVIDIA graphics |
| `gpu.nvidia-headless` | NVIDIA (headless/CUDA) |
| `battery` | Power management |
| `location` | Timezone/geolocation |

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
| `common` | Basic shell tools | bash, zsh, direnv, gh |
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
* Module file names match the option path: `my.services.tailscale` → `modules/nixos/tailscale.nix`
* Directories are used for complex modules: `modules/nixos/tailscale/`

### 5.2 Module Structure

```
modules/nixos/example/
├── default.nix      # Entrypoint (imports only)
├── options.nix      # Option declarations
├── config.nix       # Main implementation
├── services.nix     # systemd units
└── tests.nix        # Tests & assertions
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
my.services.cachix-push.enable = config.age.secrets ? "cache-token";

# Bad: Will fail if secret missing
my.services.cachix-push.tokenFile = config.age.secrets.cache-token.path;
```

---

## 7. Secrets

Secrets are managed with **agenix**. See `SECRETS.md` for the full reference.

* Encryption rules: `secrets/secrets.nix` — which keys can decrypt which `.age` files
* Encrypted blobs: `secrets/<category>/<name>.age`
* Catalog: `modules/nixos/secrets/catalog.nix` — maps logical paths to agenix names
* Decryption: At activation time via SSH host keys → `/run/agenix/<name>`

**Key patterns:**
```nix
config.age.secrets."<name>".path   # → /run/agenix/<name>
config.age.secrets ? "<name>"      # existence guard (use this!)
```

**Agent rule:** Never commit plaintext secrets. Always guard secret access with
the `?` existence check — CI builds disable secrets and will fail on bare
`config.age.secrets.<name>.path` references.

---

## 8. Common Tasks

| Task | Command |
|------|---------|
| Activate current host | `nix run` |
| Update all flake inputs | `nix flake update` or `nix run .#update` |
| Update specific inputs | `nix flake lock --update-input nixpkgs --update-input home-manager` |
| Format the tree | `nix fmt` |
| Build all outputs (CI) | `nix --accept-flake-config run github:juspay/omnix ci build` |
| Check flake | `nix flake check --no-build` |
| Test specific host | `nix run .#test run (hostname)` |
| List hosts | `nix run .#test list` |
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

## Summary

**For Agents:**

1. Host configs should be **minimal** and **declarative**
2. Use **profiles** (`my.profiles.*`, `my.homeProfiles.*`) for common patterns
3. Import **`nixosModules.common`** for base functionality
4. Set `networking.hostName` and `nixpkgs.hostPlatform`
5. Follow the **AGENT.md** hierarchy for detailed conventions
