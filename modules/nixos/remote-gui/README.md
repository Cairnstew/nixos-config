# remote-gui

Virtual X display (Xvfb) shared over VNC (x11vnc) so GUI apps on a headless
box can be viewed from another host — e.g. running Prism Launcher on the
server and watching it from the desktop.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.remoteGui.enable` | `false` | Enable the virtual display |
| `my.services.remoteGui.display` | `:10` | X display number |
| `my.services.remoteGui.screen` | `1920x1080x24` | Xvfb geometry |
| `my.services.remoteGui.vnc.enable` | `true` | Share via x11vnc |
| `my.services.remoteGui.vnc.port` | `5900` | VNC TCP port |
| `my.services.remoteGui.vnc.listenAddress` | `0.0.0.0` | VNC bind address |
| `my.services.remoteGui.vnc.passwordFile` | `null` | VNC password file (first line) |
| `my.services.remoteGui.vnc.openFirewall` | `false` | Open the VNC port in the firewall |
| `my.services.remoteGui.windowManager` | `null` | Optional WM (e.g. `pkgs.openbox`) |
| `my.services.remoteGui.apps.<name>.command` | — | App launch command |
| `my.services.remoteGui.apps.<name>.user` | primary user | User the app runs as |
| `my.services.remoteGui.apps.<name>.autostart` | `true` | Start at boot |
| `my.services.remoteGui.apps.<name>.restart` | `true` | Restart on crash |
| `my.services.remoteGui.apps.<name>.extraEnv` | `{}` | Extra env vars |

## Usage Example

```nix
my.services.remoteGui = {
  enable = true;
  windowManager = pkgs.openbox; # window decorations / focus
  apps.prismlauncher = {
    command = "${pkgs.prismlauncher}/bin/prismlauncher";
  };
};
```

## Connecting From the Client

Any VNC client works. Over the tailnet the port is reachable without a
firewall rule (tailscale0 is a trusted interface):

```bash
# tigervnc
vncviewer server.tailXXXX.ts.net:5900
# or a GUI client (GNOME Connections, Remmina, …)
```

For non-tailnet access, either set `vnc.openFirewall = true` or tunnel:
`ssh -L 5900:localhost:5900 server && vncviewer localhost:5900`.

## Notes

- `-nolisten tcp` on Xvfb means only local processes reach the display; x11vnc
  is the only network surface.
- `-ac` on Xvfb disables X auth (harmless: display is Unix-socket-only).
- No password by default — rely on tailnet trust, or set `vnc.passwordFile`
  (an `agenix` secret works).
- The virtual display has no audio and no GPU acceleration (software
  rendering), fine for the Prism Launcher UI.
- The app runs via `User=<user>`; point `command` at an absolute store path so
  it does not depend on the user's login PATH.
