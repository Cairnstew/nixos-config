# Suwayomi

Manga reader server (Tachidesk-compatible) with systemd service and optional Tailscale binding.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.services.suwayomi.enable` | bool | false | Enable Suwayomi manga reader server |
| `my.services.suwayomi.package` | package | `pkgs.suwayomi-server` | Suwayomi package |
| `my.services.suwayomi.dataDir` | path | `/var/lib/suwayomi-server` | Data directory |
| `my.services.suwayomi.user` | string | `suwayomi` | Service user |
| `my.services.suwayomi.group` | string | `suwayomi` | Service group |
| `my.services.suwayomi.extraReadWritePaths` | list of path | `[]` | Additional writable directories |
| `my.services.suwayomi.openFirewall` | bool | false | Open firewall port |
| `my.services.suwayomi.autoBindTailscaleIp` | bool | false | Bind to Tailscale IP at runtime |
| `my.services.suwayomi.settings.server.ip` | string | `127.0.0.1` | Bind IP |
| `my.services.suwayomi.settings.server.port` | port | `4567` | Listen port |
| `my.services.suwayomi.settings.server.authMode` | enum | `"none"` | Auth mode (`none`, `basic_auth`, `simple_login`, `ui_login`) |
| `my.services.suwayomi.settings.server.authUsername` | null or string | `me.username` | Auth username |
| `my.services.suwayomi.settings.server.authPasswordFile` | null or path | null | Auth password file path |
| `my.services.suwayomi.settings.server.downloadAsCbz` | bool | false | Download chapters as .cbz |
| `my.services.suwayomi.settings.server.systemTrayEnabled` | bool | false | System tray icon (X11) |
| `my.services.suwayomi.settings.server.extensionRepos` | list of string | `[]` | Extension repository URLs |

## Usage

```nix
my.services.suwayomi = {
  enable = true;
  openFirewall = true;
  settings.server = {
    port = 4567;
    authMode = "basic_auth";
    authPasswordFile = config.age.secrets."suwayomi-password".path;
  };
};
```

## Dependencies

- **NixOS modules**: networking.firewall, systemd
- **Flake inputs**: none

## Notes

- Service user/group are created unconditionally (even when disabled) so agenix secret chown works.
- Auth password is injected via the `TACHIDESK_SERVER_AUTH_PASSWORD` environment variable.
- The `server.conf` HOCON config is generated on first service start only; subsequent edits persist.
- `autoBindTailscaleIp` resolves via `tailscale ip -4` at runtime and falls back to `settings.server.ip`.
