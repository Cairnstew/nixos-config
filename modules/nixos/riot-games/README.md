# Riot Games (League of Legends / Teamfight Tactics)

Dual-boot bootstrap for Riot titles that cannot run on Linux, plus scrcpy
mirroring of the Android TFT client. **No Wine path exists** — this module does
not (and cannot) run the game on Linux.

## Why there is no Wine/Proton option

Riot's Vanguard is a Windows kernel-mode anti-cheat. Riot's own statement
(2024-04-11, still operative): the Wine/Lutris implementation "will not be able
to satisfy the Vanguard driver requirements … Linux does not currently afford us
sufficient ability to attest boot state or kernel modules".

| Title | Linux status |
|-------|--------------|
| League of Legends (desktop) | Denied — Vanguard |
| TFT (desktop client) | Same client, same Vanguard |
| TFT (Android via Waydroid) | Dead — mobile Vanguard `libmvg.so` (PBE 2026-01-09, production 2026-08-26) |
| TFT (real phone + scrcpy) | Works — the phone runs the game |
| Windows dual-boot | Works |

Sources: leagueoflegends.com/en-us/news/dev/dev-vanguard-x-lol,
areweanticheatyet.com/game/league-of-legends (Denied), leagueoflinux.org
(archived post-Vanguard). VMs, hypervisor masking and anti-cheat workarounds are
deliberately not supported: Vanguard treats them as tampering.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.riotGames.enable` | `false` | Enable the launchers |
| `my.programs.riotGames.leagueOfLegends.enable` | `true` | Desktop entry for League |
| `my.programs.riotGames.teamfightTactics.enable` | `true` | Desktop entry for TFT |
| `my.programs.riotGames.windows.bootEntry` | `"Windows 11"` | Exact GRUB menu title of the Windows install |
| `my.programs.riotGames.mobileMirror.enable` | `false` | Install scrcpy + `tft-mobile` |
| `my.programs.riotGames.mobileMirror.maxSize` | `1920` | scrcpy `--max-size` |
| `my.programs.riotGames.mobileMirror.maxFps` | `60` | scrcpy `--max-fps` |
| `my.programs.riotGames.mobileMirror.extraArgs` | `[]` | Extra scrcpy arguments |
| `my.programs.riotGames.extraPackages` | `[]` | Extra system packages |

## Usage

```nix
my.programs.riotGames = {
  enable = true;
  mobileMirror.enable = true;
};
```

Desktop entries added: *League of Legends (reboot to Windows)*, *Teamfight
Tactics (reboot to Windows)*, and *Teamfight Tactics (Android mirror)*.

`boot-to-windows` (root helper, NOPASSWD for its owner only) verifies the menu
entry exists in `/boot/grub/grub.cfg`, runs `grub-reboot "<entry>"` (one-shot
`next_entry` in `/boot/grub/grubenv`), then reboots. The permanent EFI boot
order is untouched.

TFT on a phone and mirrored to the desktop:

```bash
tft-mobile --pair 192.168.1.50:37123 123456   # once, from Wireless debugging
tft-mobile 192.168.1.50:37000                 # connect + mirror
tft-mobile                                    # mirror an already-visible device
```

## Notes

- The module asserts at eval time that GRUB is enabled and that
  `windows.bootEntry` matches a `menuentry` in `boot.loader.grub.extraEntries`
  (see `configurations/nixos/desktop/default.nix`), so a stale title fails the
  build instead of arming a non-existent boot entry.
- scrcpy mirrors *and* forwards keyboard/mouse; the TFT mobile UI is built for
  touch, so expect a suboptimal layout versus the desktop client.
- Other Riot titles that do run on Linux (Legends of Runeterra, Bandle Tale,
  Ruined King) are unrelated to this module and need no special handling.
