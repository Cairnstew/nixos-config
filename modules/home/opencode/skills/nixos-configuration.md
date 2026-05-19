# NixOS Configuration

> Skill for working with this NixOS/nix-darwin configuration repository

## Repository Structure

This is a multi-system Nix configuration using:
- **flake-parts**: Module system for flake outputs
- **nixos-unified**: Auto-wiring for configurations and modules
- **agenix**: Secret management

```
.
├── configurations/          # Host configurations
│   ├── nixos/              # NixOS hosts
│   ├── darwin/             # macOS hosts (dormant)
│   └── home/               # Standalone home-manager configs
├── modules/
│   ├── nixos/              # NixOS modules
│   ├── darwin/             # nix-darwin modules
│   ├── home/               # Home Manager modules
│   └── flake-parts/        # Flake-level modules
├── overlays/               # Nixpkgs overlays
├── packages/               # Custom packages
└── secrets/                # Agenix secrets
```

## Key Conventions

### Always Import `nixosModules.common`

Every NixOS configuration must import the common module:

```nix
{ flake, ... }:
{
  imports = [ flake.inputs.self.nixosModules.common ];
  
  networking.hostName = "myhost";
  nixpkgs.hostPlatform = "x86_64-linux";
}
```

### Use Profiles

Don't manually enable services. Use profiles:

```nix
# System profiles
my.profiles.workstation.enable = true;   # Desktop/laptop
my.profiles.server.enable = true;        # Headless
my.profiles.desktop.gnome.enable = true; # GNOME desktop
my.profiles.gpu.mesa.enable = true;      # Intel/AMD graphics

# Home profiles
my.homeProfiles.common.enable = true;    # Shell, basic tools
my.homeProfiles.desktop.enable = true;   # GUI apps
```

### All Custom Options Under `my.*`

```nix
# Good
options.my.services.myservice = { ... };

# Bad - don't do this
options.services.myservice = { ... };
```

## Common Tasks

### Adding a New Module

1. Create directory: `mkdir modules/nixos/mymodule/`
2. Create required files:
   - `default.nix` - Import manifest
   - `meta.nix` - Machine-readable metadata
   - `options.nix` - Option declarations
   - `config.nix` - Implementation
   - `tests.nix` - Tests
   - `README.md` - Human docs
3. Follow the module schema from `modules/AGENT.md`

### Adding a New Host

1. Create directory: `mkdir configurations/nixos/myhost/`
2. Create `default.nix` with host configuration
3. Import common: `flake.inputs.self.nixosModules.common`
4. Set required: `networking.hostName`, `nixpkgs.hostPlatform`
5. Enable appropriate profiles

### Updating Inputs

```bash
# Update all
nix flake update

# Update specific
nix flake lock --update-input nixpkgs
```

### Building and Testing

```bash
# Build current host
nix run

# Build specific host
nixos-rebuild switch --flake .#hostname

# Test without building
nix flake check --no-build

# Format code
nix fmt
```

## Module Categories

| Category | Path | Purpose |
|----------|------|---------|
| System | `modules/nixos/` | NixOS-specific |
| Darwin | `modules/darwin/` | macOS-specific |
| Home | `modules/home/` | Home Manager |
| Flake-parts | `modules/flake-parts/` | Flake outputs |

## Important Files

| File | Purpose |
|------|---------|
| `flake.nix` | Flake entry point |
| `AGENTS.md` | Top-level conventions |
| `modules/AGENT.md` | Module conventions |
| `configurations/AGENT.md` | Host config conventions |
| `modules/home/opencode/AGENT.md` | OpenCode module docs |

## Secret Management

Use agenix for secrets:

1. Add to `secrets/secrets.nix`
2. Encrypt: `agenix -e secret-name`
3. Use in config: `config.age.secrets.<name>.path`
4. Check existence before use: `config.age.secrets ? "name"`

Never commit plaintext secrets!

## Testing

- L0: Nix assertions (always required)
- L1: systemd probes
- L2: Smoke tests
- L3: NixOS VM tests (for critical modules)

## Troubleshooting

### "Option does not exist"

- Ensure you're importing `nixosModules.common`
- Check the option path is under `my.*`

### "Infinite recursion"

- Check for circular imports
- Ensure proper `lib.mkIf cfg.enable` gating

### "Secret not found"

- Verify agenix identity is set up
- Check secret is declared in `secrets.nix`
- Ensure host has access to the secret
