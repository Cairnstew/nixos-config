# GNOME Extension

Declarative custom GNOME Shell extensions with inline Nix configuration injection.

Define custom GNOME Shell extensions directly in your Nix config using
`my.gnomeExtensions.custom.extensions`. Extension code supports Nix string
interpolation, so you can inject `config.*` values at build time.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.gnomeExtensions.custom.extensions.<name>.enable` | `false` | Enable this extension |
| `my.gnomeExtensions.custom.extensions.<name>.uuid` | `"<name>@custom"` | Extension UUID |
| `my.gnomeExtensions.custom.extensions.<name>.name` | `"<name>"` | Display name |
| `my.gnomeExtensions.custom.extensions.<name>.description` | `""` | Short description |
| `my.gnomeExtensions.custom.extensions.<name>.version` | `1` | Version number |
| `my.gnomeExtensions.custom.extensions.<name>.shellVersions` | `["49"]` | Supported GNOME Shell versions |
| `my.gnomeExtensions.custom.extensions.<name>.url` | `""` | Website URL |
| `my.gnomeExtensions.custom.extensions.<name>.extensionJs` | `""` | Main extension code (inline text) |
| `my.gnomeExtensions.custom.extensions.<name>.stylesheetCss` | `""` | Optional stylesheet CSS |
| `my.gnomeExtensions.custom.extensions.<name>.extraFiles` | `{}` | Extra source files (path or inline) |

## Usage Example

```nix
{ config, flake, ... }:
{
  my.gnomeExtensions.custom.extensions = {
    host-info = {
      enable = true;
      name = "Host Info";
      description = "Shows NixOS host info in the top bar";
      extensionJs = ''
        const St = imports.gi.St;
        const PanelMenu = imports.ui.panelMenu;
        const Main = imports.ui.main;

        const hostname = "${config.networking.hostName}";
        const username = "${flake.config.me.username}";

        const indicator = new PanelMenu.Button(0.0, "host-info", false);
        const icon = new St.Icon({
          icon_name: "computer-symbolic",
          style_class: "system-status-icon"
        });
        indicator.add_child(icon);

        const label = new St.Label({
          text: hostname,
          y_align: Clutter.ActorAlign.CENTER,
          style_class: "host-info-label"
        });
        indicator.add_child(label);

        Main.panel.addToStatusArea("host-info", indicator);
      '';
    };
  };
}
```

## Notes

- Extensions are written to `~/.local/share/gnome-shell/extensions/<uuid>/`.
- After enabling, restart GNOME Shell (<kbd>Alt</kbd>+<kbd>F2</kbd>, type `r`, press <kbd>Enter</kbd>).
- Use `journalctl /usr/bin/gnome-shell -f` to debug extension errors.
- For GNOME Shell API reference, see https://gjs.guide/extensions/.
