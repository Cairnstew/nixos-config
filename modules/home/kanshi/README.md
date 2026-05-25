# Kanshi

Wayland output management daemon — automatically configures displays
when monitors are connected/disconnected (e.g. laptop docking).

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable kanshi for this user |
| `package` | package | pkgs.kanshi | The kanshi package |
| `settings` | list | [ ] | Ordered list of directives (see below) |
| `systemdTarget` | str | `graphical-session.target` | systemd target binding |

## Usage

```nix
my.services.kanshi = {
  enable = true;
  settings = [
    {
      profile = {
        name = "undocked";
        outputs = [
          { criteria = "eDP-1"; status = "enable"; position = "0,0"; }
        ];
      };
    }
    {
      profile = {
        name = "docked";
        outputs = [
          { criteria = "eDP-1";   status = "disable"; }
          { criteria = "DP-1";    status = "enable";  position = "0,0"; transform = "90"; }
          { criteria = "DP-2";    status = "enable";  position = "2160,0"; }
        ];
      };
    }
  ];
};
```

## Notes

- Upstream docs: [kanshi(5)](https://man.archlinux.org/man/kanshi.5)
- **wlroots-only** — requires a compositor that implements the
  `wlr-output-management-unstable-v1` protocol (Sway, Hyprland, River, etc.).
  Does **not** work with GNOME/Mutter or KDE/KWin.
  For GNOME, use `gnome-monitor-config` instead.
- Profile switching happens automatically based on connected outputs
