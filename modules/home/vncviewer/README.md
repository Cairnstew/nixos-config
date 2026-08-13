# vncviewer

VNC viewer client with per-connection launchers for viewing remote GUI apps on
other hosts — the client-side counterpart to `my.services.remoteGui` (Xvfb +
x11vnc). Each connection gets a `vnc-<name>` command and a desktop entry.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.vncviewer.enable` | `false` | Enable the VNC viewer |
| `my.programs.vncviewer.package` | `pkgs.tigervnc` | Viewer package (provides `vncviewer`) |
| `my.programs.vncviewer.connections.<name>.host` | — | VNC server hostname/IP |
| `my.programs.vncviewer.connections.<name>.port` | `5900` | VNC server port |
| `my.programs.vncviewer.connections.<name>.passwordFile` | `null` | VNC password file (first line) |
| `my.programs.vncviewer.connections.<name>.viewOnly` | `false` | No keyboard/mouse input |
| `my.programs.vncviewer.connections.<name>.fullscreen` | `false` | Start fullscreen |
| `my.programs.vncviewer.connections.<name>.scale` | `null` | Scaling percentage (10–400) |
| `my.programs.vncviewer.connections.<name>.extraArgs` | `[]` | Extra `vncviewer` args |

## Usage Example

```nix
my.programs.vncviewer = {
  enable = true;
  connections.server = {
    host = "server.tail685690.ts.net";
    port = 5900;
    viewOnly = true;
  };
};
```

Connecting is then either `vnc-server` on a terminal or picking "VNC: server"
from the app launcher.

## Notes

- The wrapper scripts live in `home.packages` and are re-generated whenever the
  config changes, so the host/port/password are always in sync with this repo.
- Password files can point at an agenix secret path; guard the secret with
  `config.age.secrets ? "name"` in the host config so hosts without it still
  evaluate.
- Over the tailnet the VNC port is reachable with no firewall rule (tailscale0
  is a trusted interface); see `modules/nixos/remote-gui/README.md`.
