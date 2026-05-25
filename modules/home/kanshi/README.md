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
- Requires a Wayland session (GNOME, KDE, Sway, Hyprland, etc.)
- Profile switching happens automatically based on connected outputs
