# Tor Browser

Privacy-focused Tor Browser with optional system Tor daemon integration.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.programs.tor-browser.enable` | bool | false | Enable Tor Browser |
| `my.programs.tor-browser.package` | null or package | null | Custom package override |
| `my.programs.tor-browser.installMethod` | enum | `"auto"` | Install target (`auto`, `home`, `system`) |
| `my.programs.tor-browser.wrapper.useIPCTorService` | bool | false | Use system Tor daemon IPC |
| `my.programs.tor-browser.wrapper.disableContentSandbox` | bool | false | Disable content sandbox |
| `my.programs.tor-browser.wrapper.extraPrefs` | lines | `""` | Extra Firefox preferences |
| `my.programs.tor-browser.wrapper.audioSupport` | bool | true | Enable audio playback |
| `my.programs.tor-browser.wrapper.waylandSupport` | bool | true | Enable Wayland |
| `my.services.tor.enable` | bool | false | Enable system Tor daemon |
| `my.services.tor.openFirewall` | bool | false | Open Tor relay ports |
| `my.services.tor.client.enable` | bool | false | Route apps through Tor SOCKS |
| `my.services.tor.client.socksPort` | port | `9050` | SOCKS proxy port |
| `my.services.tor.relay.enable` | bool | false | Run a Tor relay |
| `my.services.tor.relay.role` | enum | `"relay"` | Relay type (`relay`, `bridge`, `exit`, `private-bridge`) |
| `my.services.tor.settings` | attrs | `{}` | Raw torrc settings |

## Usage

```nix
my.programs.tor-browser = {
  enable = true;
  wrapper.useIPCTorService = true;
};
my.services.tor = {
  enable = true;
  client.enable = true;
};
```

## Dependencies

- **NixOS modules**: services.tor, home-manager (optional)
- **Flake inputs**: none

## Notes

- `installMethod = "auto"` prefers home-manager if enabled, otherwise uses `environment.systemPackages`.
- When `wrapper.useIPCTorService` is enabled, the Tor Browser will connect to the system Tor daemon via a control socket instead of using its bundled Tor.
- Assertions prevent `installMethod = "home"` if home-manager is not enabled.
