# Houdini

SideFX Houdini — 3D animation, visual effects, and procedural generation software.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.houdini.enable` | `false` | Enable Houdini |
| `my.programs.houdini.package` | `pkgs.houdini` | Houdini package to use |
| `my.programs.houdini.licenseServer` | `null` | Remote license server (`host:port`) |
| `my.programs.houdini.extraEnv` | `{}` | Extra environment variables |

## Usage Example

### Basic Installation

```nix
my.programs.houdini.enable = true;
```

### With Remote License Server

```nix
my.programs.houdini = {
  enable = true;
  licenseServer = "license-server.local:1715";
};
```

## License

Houdini is proprietary unfree software. You must have a valid SideFX license
to use it. The module configures `nixpkgs.config.allowUnfree` for Houdini
automatically.

## Notes

- Requires `nixpkgs.config.allowUnfree = true` (set automatically)
- `HFS` environment variable points to the Houdini installation root
- License server can be configured via `licenseServer` option or by setting
  the `sesi_license` environment variable manually
- The `hserver` (local license daemon) is started automatically when no remote
  license server is configured
