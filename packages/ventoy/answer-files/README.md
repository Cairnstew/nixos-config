# Windows Unattended Answer Files

This directory contains XML templates for Windows unattended installation via
Ventoy. Each file is processed by `modules/flake-parts/ventoy/answer-files.nix`
which substitutes `@VAR@` placeholders at Nix eval time.

## Templates

| File | Profile | Use Case |
|------|---------|----------|
| `dev.xml` | Developer workstation | Auto-logon, short timeout, dev tools |
| `minimal.xml` | Minimal install | User creates account at first boot |
| `domain.xml` | Corporate domain join | Domain-joined machine |
| `kiosk.xml` | Kiosk mode | Single-app kiosk, 999 auto-logons |
| `dual-boot.xml` | Dual-boot setup | Wipes disk, minimal interaction |

## Variables

Each template can use these `@VAR@` placeholders. They are defined in
`answer-files.nix` under `answerFileConfigs` per profile, with system-wide
defaults from `ventoy.answerFileSettings`:

| Variable | Source | Description |
|----------|--------|-------------|
| `@productKey@` | `buildAnswer` call | Windows product key |
| `@computerName@` | per-profile config | Computer name |
| `@username@` | per-profile config or `ventoy.answerFileSettings.username` | Local account username |
| `@password@` | per-profile config or `ventoy.answerFileSettings.password` | Local account password |
| `@autoLogonCount@` | per-profile config | Number of auto-logins |
| `@lang@` | `buildAnswer` call (default: `en-GB`) | Display language |
| `@timezone@` | `buildAnswer` call (default: `GMT Standard Time`) | Time zone |
| `@arch@` | `buildAnswer` call | Architecture (`amd64`) |
| `@archId@` | derived from `@arch@` | Architecture ID |
| `@networkLocale@` | `buildAnswer` call | Network location |
| `@protectYourPC@` | `buildAnswer` call | Privacy settings |
| `@diskId@` | `ventoy.answerFileSettings.diskId` | Target disk ID |
| `@wipeDiskBlock@` | `wipe-disk.xml` partial | Disk wipe XML block (conditional) |

## Adding a New Profile

1. Create a new XML file here (e.g., `server.xml`).
2. Add the template path to `answerTemplates` in
   `modules/flake-parts/ventoy/answer-files.nix`.
3. Add a config entry under `answerFileConfigs`.
4. The profile is automatically exported as
   `packages.windows-answ-pro-<name>`.
5. Wire it into `ventoy.settings.auto_install` in
   `modules/flake-parts/ventoy-config.nix`.

## Partials

- `partials/wipe-disk.xml` — Included by the `dual-boot` profile to clear the
  target disk before installation. Injected at `@wipeDiskBlock@`.

## Disk ID

When booting from Ventoy, the USB drive is usually disk 0 and the internal
drive is disk 1. Adjust `ventoy.answerFileSettings.diskId` per-host:

```nix
ventoy.answerFileSettings.diskId = "1";  # Internal drive with Ventoy USB
```

On a non-Ventoy install (e.g., direct PXE or DVD), the internal drive is
usually disk 0:
