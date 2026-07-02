# Live ISO

Declarative named live NixOS ISO configurations. Each entry becomes a flake package `live-iso-<name>`.

## Options (`my.live.isos.<name>`)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `baseModule` | enum | "minimal" | Base installer CD module preset |
| `hostPlatform` | str | "x86_64-linux" | System architecture for the ISO |
| `extraModules` | list of raw | [] | Extra NixOS modules for the ISO |
| `extraPackages` | list of package | [] | Extra packages in the live image |
| `sshKeys` | list of str | [] | SSH public keys authorized for root |
| `rootPassword` | null or str | null | Initial hashed root password |
| `squashfsCompression` | null or str | null | Squashfs compression algorithm |
| `kernelParams` | list of str | [] | Additional kernel boot parameters |
| `enableSSH` | bool | true | Enable SSH daemon with PermitRootLogin |
| `enableFlakes` | bool | true | Enable nix-command and flakes |
| `includeChannel` | bool | false | Provide initial NixOS channel copy |
| `isoName` | null or str | null | Custom ISO filename |
| `volumeID` | null or str | null | ISO volume label (max 32 chars) |
| `extraContents` | list of {source, target} | [] | Extra files at specific paths in the ISO |
| `tailscale.enable` | bool | false | Enable Tailscale with accept-routes |
| `tailscale.authKeyFile` | null or str | null | Path to Tailscale auth key in ISO root |
| `tailscale.authKeyEncryptedSource` | null or path | null | Encrypted .age auth key to embed |
| `ventoy` | bool | false | Deploy to Ventoy USB during ventoy-deploy |

## Usage

```nix
my.live.isos.diagnostics = {
  baseModule = "minimal";
  extraPackages = [ pkgs.htop pkgs.iotop ];
  sshKeys = [ "ssh-ed25519 AAAA... user@host" ];
};
```

## Dependencies

- **Flake-parts module**: `ventoy` (consumes ISOs for deployment)

## Notes

- This is an options-only module; ISOs are built by the flake-parts ventoy layer.
- Base module presets: minimal, graphical, graphical-kde, graphical-combined.
- Each ISO can optionally auto-connect to Tailscale with an encrypted auth key.
