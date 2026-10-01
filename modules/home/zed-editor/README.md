# zed-editor

Zed editor module for Home Manager. Configures `programs.zed-editor` with
typed options for common settings.

## Options

All options live under `my.programs.zed-editor`.

### Core
- `enable` — Enable Zed
- `package` — Zed package to use
- `defaultEditor` — Set EDITOR/VISUAL to zed
- `extensions` — Extensions to install on startup
- `mutableUserSettings/Keymaps/Tasks/Debug` — Whether Zed can overwrite Nix-managed configs

### Appearance
- `theme` — Theme name or `{ dark, light, mode }` attrset
- `customThemes` — Custom theme definitions (auto-generates Catppuccin Mocha from me.colorScheme)
- `fontFamily` / `fontSize` — Base font settings
- `uiFontSize` / `bufferFontSize` — UI/buffer-specific font sizes
- `terminalFontFamily` / `terminalFontSize` — Terminal panel font settings

### Editor
- `vimMode`, `relativeLineNumbers`, `tabSize`, `softWrap`
- `formatOnSave`, `autosave`, `cursorShape`
- `inlayHints`, `indentGuides`, `showWhitespaces`
- `confirmQuit`, `restoreSessions`, `scrollPastEnd`

### Git
- `git.gutter` — Which files show git gutter indicators
- `git.inlineBlame` / `git.inlineBlameDelay` — Inline blame annotations

### Terminal
- `terminal.alternateScroll`, `terminal.blinking`, `terminal.copyOnSelect`
- `terminal.shell` — Custom shell path
- `terminal.env` — Extra environment variables

### Pass-through
- `extraSettings` — Raw attrs merged on top of computed settings
- `userKeymaps`, `userTasks`, `userDebug` — Raw JSON config files

### Remote development

Zed runs its UI locally and the language servers, tasks, and terminal on a
remote host over SSH. Connections live in `ssh_connections` in `settings.json`
and appear in Zed's Remote Projects dialog (<kbd>ctrl-alt-shift-o</kbd>).

All building happens in `remote.nix`, a pure module both `config.nix` and
`tests.nix` use — so the generated JSON is tested without needing a host that
enables remote development.

**`tailnetConnections`** generates one connection per host in
`flake.config.tailnet` (`config.nix`):

| Option | Default | Purpose |
|---|---|---|
| `enable` | `false` | Generate connections for tailnet hosts |
| `hostField` | `magicDnsName` | Which tailnet field to dial: `magicDnsName`, `hostname`, or `ip` |
| `include` | `[ ]` | Whitelist of host keys; empty means all |
| `exclude` | `[ ]` | Host keys to skip (wins over `include`) |
| `defaultProjects` | `[ "~" ]` | Paths opened on each generated host |
| `uploadBinaryOverSsh` | `true` | Upload the server binary (works on offline remotes) |
| `args` | `[ ]` | Extra SSH args for every generated connection |
| `hosts` | `{ }` | Per-host overrides, keyed by tailnet key |

**`hosts.<key>`** overrides a single host. Unset fields fall back to the
tailnet-wide default, and `host` may be omitted so the address comes from the
tailnet record:

```nix
tailnetConnections = {
  enable = true;
  # Don't offer yourself or the WSL box as a remote target.
  exclude = [ "desktop-dlstflt" "wsl" ];
  # Prefer specific project dirs over ~ — Zed is slow on very large home dirs.
  defaultProjects = [ "~/projects" ];
  hosts = {
    server = {
      projects = [{ paths = [ "~/git" ]; }];
      portForwards = [
        { localPort = 8080; remotePort = 80; }
        { localPort = 5432; remotePort = 5432; }
      ];
    };
    # Hop through a bastion with -J.
    wsl = { args = [ "-J" "desktop-dlstflt" ]; };
    # Skip without touching `exclude`.
    minimal = { enable = false; };
  };
};
```

**`sshConnections`** holds explicit entries for anything not in the tailnet
(a bastion, a LAN box, a cloud VM). It is merged with the generated list;
entries are deduped by host/user/port and **explicit entries win**, so writing
one by hand replaces the generated entry for that host rather than duplicating
it. `sshConnections` entries must set `host`.

```nix
sshConnections = [
  {
    host = "bastion.example.com";
    username = "seanc";
    nickname = "Bastion";
    projects = [{ paths = [ "~/dotfiles" ]; }];
    portForwards = [ { localPort = 5432; remotePort = 5432; } ];
  }
];
```

### How connections resolve

Zed shells out to the system `ssh` and inherits `~/.ssh/config`, so hosts
resolve through the aliases `modules/nixos/tailscale` writes to
`~/.ssh/config.d/tailscale`. `my.services.ssh.enable` must be on (it is by
default on desktop/laptop) or none of the tailnet hostnames resolve. Because
that file is generated at runtime, connections use MagicDNS names rather than
the tailnet IPs baked into `config.nix` — which also means they keep working
when a host's IP changes.

Keep the `args` option empty unless you need something specific: most SSH
concerns (identity files, `IdentityAgent` for 1Password, `ControlMaster`
multiplexing) are already handled by `my.services.ssh` in `~/.ssh/config`.

Zed's own settings for a remote session are read from the *remote* host's
`settings.json`, not yours — see
<https://zed.dev/docs/remote-development>.

## Example usage

```nix
my.programs.zed-editor = {
  enable = true;
  vimMode = true;
  fontSize = 14;
  extensions = [ "nix" "rust" "toml" "yaml" ];
  git.inlineBlame = true;

  tailnetConnections = {
    enable = true;
    exclude = [ "wsl" ];
  };
};
```
