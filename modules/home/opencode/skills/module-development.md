# Module Development

> Skill for creating NixOS/Home Manager modules following this repo's conventions

## Module Structure

Every module directory must contain:

```
modules/<category>/<name>/
├── default.nix      # Import manifest ONLY (no logic)
├── meta.nix         # Machine-readable metadata
├── options.nix      # Option declarations under `my.*`
├── config.nix       # Main implementation
├── tests.nix        # Required tests
├── README.md        # Human documentation
└── AGENT.md         # (Optional) Agent-specific guidance
```

## default.nix

The entrypoint must only contain imports:

```nix
{ ... }:
{
  imports = [
    ./meta.nix
    ./options.nix
    ./config.nix
    ./tests.nix
  ];
}
```

**Rule:** Never put logic in default.nix!

## meta.nix

Machine-readable contract:

```nix
{
  name = "myservice";
  description = "Brief description of what this module does";
  category = "services";  # networking, desktop, media, etc.
  tags = [ "service" "daemon" "network" ];
  provides = [ "my.services.myservice" ];
  expects = [ "my.networking.firewall" ];  # Soft dependencies
  complexity = "medium";  # simple | medium | complex
  tested = true;  # Set when tests.nix has meaningful coverage
}
```

Must evaluate without function arguments!

## options.nix

All options under `my.*` namespace:

```nix
{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.myservice = {
    enable = mkEnableOption "My Service" // { default = false; };
    
    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port to listen on";
    };
    
    extraConfig = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Extra configuration options";
    };
  };
}
```

## config.nix

Main implementation with proper gating:

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.myservice;
in
{
  config = lib.mkIf cfg.enable {
    # Systemd service
    systemd.services.myservice = {
      description = "My Service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.myservice}/bin/myservice --port ${toString cfg.port}";
        Restart = "always";
      };
    };
    
    # Firewall
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
```

## tests.nix

Required testing at multiple levels:

```nix
{ config, lib, ... }:
let
  cfg = config.my.services.myservice;
in
{
  # L0: Nix assertions (mandatory)
  assertions = [
    {
      assertion = !(cfg.enable && cfg.port < 1024);
      message = "my.services.myservice.port must be >= 1024";
    }
  ];
  
  # L1: systemd probes (when service exists)
  systemd.services.myservice.serviceConfig.ExecStartPost = 
    lib.mkIf cfg.enable "${pkgs.curl}/bin/curl -f http://localhost:${toString cfg.port}/health";
  
  # L2: Smoke test
  systemd.services.myservice-smoke-test = lib.mkIf cfg.enable {
    description = "Smoke test for myservice";
    serviceConfig.Type = "oneshot";
    script = ''
      echo "Testing myservice..."
      ${pkgs.curl}/bin/curl -f http://localhost:${toString cfg.port}/health || exit 1
    '';
  };
}
```

## README.md

Human documentation (≤ 50 lines):

```markdown
# My Service

One-sentence description.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.myservice.enable` | `false` | Enable the service |
| `my.services.myservice.port` | `8080` | Listen port |

## Usage Example

\`\`\`nix
my.services.myservice = {
  enable = true;
  port = 9090;
};
\`\`\`

## Notes

Any caveats or upstream links.
```

## Naming Conventions

### Option Paths

- Use camelCase: `my.services.myService.enable`
- Booleans: `my.services.<name>.enable`
- Lists: plural names `my.services.<name>.extraVolumes`
- Attrsets: singular keys `my.services.<name>.restart.policy`

### Module Names

- Match file name to option: `my.services.tailscale` → `tailscale.nix`
- Use directories for complex modules
- Flat files only for trivial one-liners

## Hard Rules

| Rule | Violation |
|------|-----------|
| All options under `my.*` | `options.services.foo` is forbidden |
| `default.nix` is import-only | No logic, only `imports = [ ... ]` |
| `meta.nix` must be pure attrset | No function args, no imports |
| Tests must not break when disabled | Gate on `cfg.enable` |
| No `home-manager.sharedModules` in NixOS | Wire at host level instead |
| No `config.system.*` in Home Manager | Not safe in standalone HM |

## Splitting Guidelines

Extract side-cars when:
- `config.nix` > 150 lines → extract `services.nix`, `packages.nix`
- > 10 options → extract `options.nix`
- Mixing system + home → extract `home.nix`
- Secrets referenced → extract `secrets.nix`
- Multiple systemd units → extract `services.nix`

## Cross-Module Dependencies

Import at configuration level, not module level:

```nix
# In host configuration, not in module/default.nix
{
  imports = [
    self.nixosModules.moduleA
    self.nixosModules.moduleB  # Depends on A
  ];
}
```

## Home Manager Integration

For NixOS modules that need HM config:

1. Expose options in NixOS module
2. Set `home-manager.users.<name>.my.programs.<thing>` in config.nix
3. Create separate `modules/home/<thing>.nix` for standalone HM

Example:

```nix
# modules/nixos/myservice/config.nix
config = lib.mkIf cfg.enable {
  home-manager.users.${cfg.user}.my.programs.myservice-client = {
    enable = true;
    serverHost = cfg.host;
  };
};
```

## Migration: Flat File → Directory

When a `.nix` file grows:

1. Create directory: `mkdir modules/nixos/foo/`
2. Move: `mv modules/nixos/foo.nix modules/nixos/foo/default.nix`
3. Extract to side-cars
4. Update `default.nix` to import-only
5. Add `meta.nix`, `tests.nix`, `README.md`

## Testing Your Module

```bash
# Check evaluation
nix flake check --no-build

# Build with your module enabled
nixos-rebuild build --flake .#testhost

# Run VM test (if L3)
nix run .#test
```
