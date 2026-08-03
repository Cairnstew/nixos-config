[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

This repository contains the NixOS / nix-darwin / Home Manager configuration for my personal systems. It uses [nixos-unified](https://nixos-unified.org) for autowiring and [flake-parts](https://flake.parts/) for modular flake structure.

## Quick Start

### Existing Systems

To activate the configuration on an existing NixOS system:

```bash
nix run
```

Or using just:

```bash
just local
```

### New Installation

1. Install NixOS (or WSL)
2. Clone this repo: `git clone https://github.com/Cairnstew/nixos-config.git`
3. Edit `config.nix` with your user information
4. Rename/adjust `./configurations/nixos/<hostname>/default.nix` for your system
5. Run `nix run`

## Systems

| Hostname | Type | Platform | Profile |
|----------|------|----------|---------|
| `laptop` | Intel Laptop | `x86_64-linux` | Workstation |
| `desktop` | AMD Desktop PC | `x86_64-linux` | Workstation + Development + Entertainment + Gaming + Media + Testing + Theming (Stylix) |
| `server` | AMD Headless Server | `x86_64-linux` | Server |
| `minimal` | Minimal host | `x86_64-linux` | Minimal + Dev |
| `wsl` | Windows Subsystem Linux | `x86_64-linux` | Minimal + Dev |

## Architecture

### Key Files

| File | Purpose |
|------|---------|
| `flake.nix` | Entry point; defines inputs and imports flake-parts modules |
| `config.nix` | User identity, tailnet hosts, AI model configurations |
| `modules/nixos/common.nix` | **Import this in all NixOS hosts** — provides base functionality |
| `modules/nixos/profiles/` | System and home profile modules (workstation, server, desktop, etc.) |
| `justfile` | Common tasks (deploy, update, cleanup) |

### Directory Layout

| Path | Flake Output | Description |
|------|--------------|-------------|
| `configurations/nixos/<host>/` | `nixosConfigurations.<host>` | NixOS host configurations |
| `configurations/darwin/<host>.nix` | `darwinConfigurations.<host>` | macOS host configurations (dormant — dir not yet present) |
| `configurations/home/<user>.nix` | `homeConfigurations.<user>` | Standalone Home Manager configs (dormant — dir not yet present) |
| `modules/nixos/` | `nixosModules.*` | NixOS modules (import via `nixosModules.common`) |
| `modules/home/` | `homeModules.*` | Home Manager modules |
| `modules/flake-parts/` | `flake` options | Flake-level modules (templates, testing, etc.) |
| `overlays/` | `overlays.*` | Package overlays |
| `packages/` | `perSystem.packages.*` | Custom packages |
| `modules/nixos/secrets/` | N/A | Agenix-encrypted secrets (flat `.age` files) |

### Profile System

Use profiles for common configuration patterns instead of manual service enablement:

**System Profiles** (`my.profiles.*`):
- `workstation` — Desktop/laptop with GUI (audio, bluetooth, printing)
- `server` — Headless server (SSH, Tailscale, no GUI)
- `development` — Dev tools (git, docker, direnv)
- `minimal` — Bare essentials only
- `gaming` — Steam and gaming tools
- `media` — Media stack (Prowlarr, Sonarr, Radarr, Jellyfin)
- `entertainment` — Gaming, music, media services
- `ai` — AI frontends (RisuAI, Open WebUI, Letta, Jan)

**Feature Profiles**:
- `desktop.gnome` / `desktop.hyprland` — Desktop environments
- `gpu.mesa` / `gpu.nvidia` / `gpu.nvidia-headless` — Graphics drivers
- `battery` — Power management
- `location` — Timezone/geolocation
- `power.desktop` / `power.laptop` — Power profiles (never-sleep vs battery-aware)
- `theming.stylix` — Stylix theming framework
- `testing` — Module smoke tests and health checks

**Home Profiles** (`my.homeProfiles.*`):
- `common` — Shell, direnv, git, basic tools
- `desktop` — GUI applications (Firefox, Discord, Obsidian)
- `development` — VSCode, dev tools
- `minimal` — Essential only
- `server` — Minimal GUI (disables Firefox, enables VS Code)

Example host configuration:

```nix
{ flake, ... }:
{
  imports = [ flake.inputs.self.nixosModules.common ];
  
  networking.hostName = "myhost";
  nixpkgs.hostPlatform = "x86_64-linux";
  
  # System profile
  my.profiles.workstation.enable = true;
  my.profiles.desktop.gnome.enable = true;
  my.profiles.gpu.mesa.enable = true;
  my.profiles.battery.enable = true;
  
  # Home profile
  my.homeProfiles.common.enable = true;
  my.homeProfiles.desktop.enable = true;
}
```

## Common Tasks

| Task | Command |
|------|---------|
| Activate current host | `nix run` or `just local` |
| Update all flake inputs | `nix flake update` or `just update` |
| Update specific inputs | `nix flake lock --update-input nixpkgs --update-input home-manager` |
| Format all Nix files | `nix fmt` (or `nixpkgs-fmt **/*.nix`) |
| Run tests | `nix run .#nixtests-run` |
| Deploy a host | `just deploy-run <host> <target>` (or `nix run .#deploy-<host> -- <target>`) |
| Clean old generations | `just fuckboot` |
| Build a host | `nix build .#<host>` (ci.yml matrix builds laptop/server/wsl) |
| Check flake evaluation | `nix flake check --no-build` |

## Secrets

Secrets are managed with [agenix-manager](https://github.com/Cairnstew/agenix-manager) using flat `.age` files. To edit a secret:

```bash
nix develop .#secrets
agenix-manager new
```

Or via plain agenix:

```bash
agenix -e modules/nixos/secrets/<name>.age -r /etc/agenix/secrets.nix
```

Encrypted blobs live in `modules/nixos/secrets/` and are declared in `secrets-manifest.json`. See `SECRETS.md` for the full reference.

## Documentation

- `AGENTS.md` — Top-level project conventions and architecture
- `modules/AGENT.md` — Module structure and conventions
- `configurations/AGENT.md` — Host configuration guide
- `modules/flake-parts/README.md` — Flake-parts layer documentation

## License

MIT — see the [license badge](https://opensource.org/licenses/MIT) at the top of this README.
