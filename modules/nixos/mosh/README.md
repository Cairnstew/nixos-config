# Mosh

mosh (mobile shell) for session persistence on flaky links. When a mesh
(VPN) restarts, the existing mosh session survives — you aren't dropped at the
SSH layer. Paired with tmux so reconnects never lose work.

**Not an independent access path**: mosh bootstraps over SSH, so it can't
rescue you from being locked out. It only makes surviving sessions painless.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.mosh.enable` | `false` | Enable mosh |
| `my.services.mosh.package` | `pkgs.mosh` | mosh package |
| `my.services.mosh.openFirewall` | `false` | Open UDP 60000-61000 globally (needed for ZeroTier/LAN paths) |
| `my.services.mosh.installTmux` | `true` | Install tmux alongside mosh |

## Usage Example

```nix
my.services.mosh = {
  enable = true;
  openFirewall = true; # also works over ZeroTier / LAN fallback
};
```

## Notes

- With `openFirewall = false`, mosh only works over the tailnet (already a
  trusted interface); UDP 60000-61000 is allowed on `tailscale0`.
- Client side: `mosh server` (requires mosh client installed).
- `withUtempter` is disabled — avoids the setgid utempter wrapper on a
  headless box.
