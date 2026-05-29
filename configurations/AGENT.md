# configurations/AGENT.md

> **Scope:** Host-specific configurations under `configurations/nixos/`, `configurations/darwin/`, and `configurations/home/`

---

## Quick Start

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
  
  # Pick profiles
  my.profiles.workstation.enable = true;
  my.profiles.desktop.gnome.enable = true;
  my.homeProfiles.common.enable = true;
  my.homeProfiles.desktop.enable = true;
}
```

---

## Configuration Structure

```
configurations/nixos/
├── laptop/                    # Laptop with GUI
│   ├── default.nix           # Host configuration
│   └── hardware-configuration.nix  # Generated hardware config
├── server/                    # Headless server
│   └── default.nix
└── wsl/                       # WSL instance
    └── default.nix
```

---

## Configuration Conventions

### 1. Minimal Boilerplate

Configurations should be declarative and minimal:

**Good:**
```nix
{ flake, ... }:
{
  imports = [ flake.inputs.self.nixosModules.common ];
  
  networking.hostName = "laptop";
  
  my.profiles.workstation.enable = true;
  my.profiles.desktop.gnome.enable = true;
  my.profiles.gpu.mesa.enable = true;
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
  # ... verbose config
}
```

### 2. Use Profiles for Common Patterns

Don't manually enable collections of services. Use profiles:

| Profile | Use Case |
|---------|----------|
| `my.profiles.workstation` | Desktop/laptop with GUI |
| `my.profiles.server` | Headless server |
| `my.profiles.minimal` | Bare essentials |
| `my.profiles.development` | Dev tools, containers |
| `my.profiles.gaming` | Steam, games |

Home profiles:

| Profile | Use Case |
|---------|----------|
| `my.homeProfiles.common` | Shell, basic tools |
| `my.homeProfiles.desktop` | GUI apps |
| `my.homeProfiles.development` | Dev tools |
| `my.homeProfiles.server` | Minimal home config |

### 3. Override Specifics, Not Defaults

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

### 4. Hardware Configuration

Hardware configs should be separate and minimal:

```nix
# configurations/nixos/myhost/default.nix
{ ... }:
{
  imports = [ 
    ./hardware-configuration.nix  # Generated
    # ...
  ];
  # No hardware settings here
}
```

### 5. Secrets Handling

Don't reference secrets directly. Use conditional guards:

```nix
# Good: Check if secret exists first
my.services.cachix-push.enable = config.age.secrets ? "cache-token";

# Bad: Will fail if secret missing
my.services.cachix-push.tokenFile = config.age.secrets.cache-token.path;
```

---

## Profile System

### System Profiles (my.profiles)

Located in: `modules/nixos/profiles/system/`

```nix
my.profiles = {
  # Role profiles (pick one)
  workstation.enable = true;      # Desktop/laptop
  server.enable = false;          # Headless
  minimal.enable = false;         # Bare bones
  
  # Feature profiles (toggle as needed)
  desktop.gnome.enable = true;
  gpu.mesa.enable = true;          # Or nvidia
  battery.enable = true;
  location.enable = true;
};
```

### Home Profiles (my.homeProfiles)

Located in: `modules/nixos/profiles/home/`

```nix
my.homeProfiles = {
  common.enable = true;         # Shell, direnv, git
  desktop.enable = true;        # Firefox, Discord, etc.
  development.enable = true;    # VSCode, dev tools
};
```

### Per-Host Home Customization

For host-specific home settings:

```nix
my.homeManager.extraConfig.my.programs = {
  # Extra programs for this host only
  steam.enable = true;
  
  # Override defaults
  firefox.enable = false;  # Don't want Firefox on this server
};
```

---

## Common Patterns

### Desktop/Laptop

```nix
{ flake, ... }:
{
  imports = [ flake.inputs.self.nixosModules.common ];
  
  networking.hostName = "laptop";
  nixos-unified.sshTarget = "seanc@laptop";
  
  my.profiles = {
    workstation.enable = true;
    desktop.gnome.enable = true;
    gpu.mesa.enable = true;
    battery.enable = true;
  };
  
  my.homeProfiles = {
    common.enable = true;
    desktop.enable = true;
  };
}
```

### Server

```nix
{ flake, ... }:
{
  imports = [ flake.inputs.self.nixosModules.common ];
  
  networking.hostName = "server";
  nixos-unified.sshTarget = "seanc@server";
  
  my.profiles = {
    server.enable = true;
    gpu.nvidia-headless.enable = true;
  };
  
  my.homeProfiles = {
    common.enable = true;
    server.enable = true;
  };
  
  # Server-specific services
  my.services.ollama.gpu.enable = true;
}
```

### WSL

```nix
{ flake, ... }:
{
  imports = [ flake.inputs.self.nixosModules.common ];
  
  wsl.enable = true;
  wsl.defaultUser = flake.config.me.username;
  
  my.profiles = {
    minimal.enable = true;
    development.enable = true;
  };
  
  my.homeProfiles.minimal.enable = true;
}
```

---

## Module Reference

### Always Available

These modules are imported by `nixosModules.common`:

- `my.services.tailscale` - VPN/mesh networking
- `my.services.ssh` - SSH daemon
- `my.secrets` - Agenix secrets management
- `my.virtualisation.docker` - Docker containers
- `my.system.audio` - Audio subsystem
- `my.system.bluetooth` - Bluetooth
- `my.system.location` - Timezone/location

### Profile Modules

Import additional profiles as needed:

- `my.profiles.workstation` - Desktop defaults
- `my.profiles.server` - Server defaults
- `my.profiles.development` - Dev tools
- `my.profiles.gaming` - Gaming setup
- `my.homeProfiles.*` - User environment profiles

---

## Troubleshooting

### "Option does not exist"

Make sure you're importing `nixosModules.common`:

```nix
imports = [ flake.inputs.self.nixosModules.common ];
```

### Profile conflicts

Check assertions - you may have conflicting profiles:

```nix
# Wrong: Can't have both
gpu.mesa.enable = true;
gpu.nvidia.enable = true;

# Correct: Pick one
gpu.mesa.enable = true;
```

### Home settings not applying

Make sure home profiles are enabled:

```nix
my.homeProfiles.common.enable = true;  # Required base
```

---

## Migration Guide

### From old structure

**Before:**
```nix
let
  me = flake.config.me;
  user = me.username;
in
{
  imports = [ self.nixosModules.default ];
  
  my.system.audio.enable = true;
  my.system.bluetooth.enable = true;
  my.programs.spotify.enable = true;
  
  home-manager.users.${user}.my.programs = {
    firefox.enable = true;
    vscode.enable = true;
  };
}
```

**After:**
```nix
{
  imports = [ flake.inputs.self.nixosModules.common ];
  
  my.profiles.workstation.enable = true;
  my.homeProfiles = {
    common.enable = true;
    desktop.enable = true;
  };
}
```

---

## See Also

- `../modules/nixos/profiles/` - Profile implementations
- `../modules/AGENT.md` - Module conventions
- `../AGENTS.md` - Top-level project conventions
