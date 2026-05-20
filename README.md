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
| `laptop` | ThinkPad/Intel Laptop | `x86_64-linux` | Workstation |
| `desktop` | AMD Desktop PC | `x86_64-linux` | Workstation |
| `server` | AMD Headless Server | `x86_64-linux` | Server |
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
| `configurations/darwin/<host>.nix` | `darwinConfigurations.<host>` | macOS host configurations (dormant) |
| `configurations/home/<user>.nix` | `homeConfigurations.<user>` | Standalone Home Manager configs |
| `modules/nixos/` | `nixosModules.*` | NixOS modules (import via `nixosModules.common`) |
| `modules/home/` | `homeModules.*` | Home Manager modules |
| `modules/flake-parts/` | `flake` options | Flake-level modules (templates, testing, etc.) |
| `overlays/` | `overlays.*` | Package overlays |
| `packages/` | `perSystem.packages.*` | Custom packages |
| `secrets/` | N/A | Agenix-encrypted secrets |

### Profile System

Use profiles for common configuration patterns instead of manual service enablement:

**System Profiles** (`my.profiles.*`):
- `workstation` — Desktop/laptop with GUI (audio, bluetooth, printing)
- `server` — Headless server (SSH, Tailscale, no GUI)
- `development` — Dev tools (git, docker, direnv)
- `minimal` — Bare essentials only

**Feature Profiles**:
- `desktop.gnome` / `desktop.plasma` — Desktop environment
- `gpu.mesa` / `gpu.nvidia` / `gpu.nvidia-headless` — Graphics drivers
- `battery` — Power management
- `location` — Timezone/geolocation

**Home Profiles** (`my.homeProfiles.*`):
- `common` — Shell, direnv, git, basic tools
- `desktop` — GUI applications (Firefox, Discord, Obsidian)
- `development` — VSCode, dev tools

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
| Run tests | `nix run .#test run [hostname]` |
| List hosts | `nix run .#test list` |
| Deploy to server | `nix run . <hostname>` |
| Clean old generations | `just fuckboot` |
| Local CI check | `nix --accept-flake-config run github:juspay/omnix ci build` |

## Secrets

Secrets are managed with [agenix](https://github.com/ryantm/agenix). To edit a secret:

```bash
agenix -e secrets/<name>.age
```

SSH public keys that can decrypt secrets are defined in `secrets/secrets.nix`.

## Documentation

- `AGENTS.md` — Top-level project conventions and architecture
- `modules/AGENT.md` — Module structure and conventions
- `configurations/AGENT.md` — Host configuration guide
- `modules/flake-parts/README.md` — Flake-parts layer documentation

## License

MIT — See [LICENSE](./LICENSE) for details.
