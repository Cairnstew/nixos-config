# 1Password

Desktop app, CLI, and SSH agent integration.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs._1password.enable` | `true` | Install the CLI and its setgid wrapper (`/run/wrappers/bin/op`) |
| `my.programs._1password.gui.enable` | `config.my.profiles.workstation.enable` | Install the desktop app, polkit policy, and 1Password SSH agent |

## Host behaviour

`enable` is on for every host, so the CLI and `/run/wrappers/bin/op` (group
`onepassword-cli`) always exist. `gui.enable` follows
`my.profiles.workstation.enable`: desktop and laptop get the app, polkit and
`IdentityAgent ~/.1password/agent.sock`; server, wsl and minimal get the CLI
only, so their normal ssh-agent keeps working. Override `gui.enable` per host
if needed.

`programs._1password` already installs the CLI, so the module sets
`my.programs.ssh-1password.install1PasswordCli = false` — the home-profile copy
is not in the `onepassword-cli` group and cannot reach the app-integration
socket.

## Usage

```nix
my.programs._1password.enable = true;
my.programs._1password.gui.enable = true; # default: workstation profile
```

The app's own settings (Settings → Security → Linux system authentication, then
Settings → Developer → *Integrate with 1Password CLI*) are machine-local,
integrity-tagged, and cannot be declared here. The desktop host starts the app
at login via `my.desktop.hyprland.core.extraExecOnce`.

## Related Modules

- **Imported by** [`modules/nixos/common.nix`](../common.nix) — enabled on all hosts via `my.*` options.
