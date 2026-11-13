# superfile

Terminal file manager (Go/Bubble Tea) with a Nix-managed `config.toml` — what
`SUPER+E` launches on Hyprland hosts.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.superfile.enable` | `false` | Install superfile and manage its config |
| `my.programs.superfile.package` | `pkgs.superfile` | Package (binary is `superfile`, not `spf`) |
| `my.programs.superfile.settings` | `{}` | Extra `config.toml` keys, merged over module defaults |
| `my.programs.superfile.themes` | `{}` | Extra theme files: `name` → TOML attrs |
| `my.programs.superfile.editor` | `""` | File editor (`e`); empty = `$EDITOR`, then `nano` |
| `my.programs.superfile.dirEditor` | `preferences.editor` | Directory editor (`E`); upstream's `vi` is absent on NixOS |
| `my.programs.superfile.previews.pdf` | `true` | Install `poppler-utils` for first-page PDF thumbnails |
| `my.programs.superfile.previews.video` | `false` | Install `ffmpeg` for video thumbnails |
| `my.programs.superfile.extraPackages` | `[]` | Extra PATH packages |

Helpers are derived from `settings`: `bat` for `code_previewer = "bat"`,
`exiftool` for `metadata`, `zoxide` for `zoxide_support`.

## Usage Example

```nix
my.programs.superfile = {
  enable = true;
  settings = {
    theme = "my-palette";
    file_preview_width = 6;
    metadata = true;           # pulls in exiftool automatically
    open_with.md = "obsidian"; # GUI only: runs detached, no TTY
  };
  themes.my-palette = {
    code_syntax_highlight = "catppuccin-mocha";
    full_screen_bg = "#1e1e2e";
  };
};
```

## Notes

* **No plugin API.** Upstream's "plugins" are three compiled-in toggles
  (`metadata`, `enable_md5_checksum`, `zoxide_support`) plus `open_with`; nothing
  loads external code, so a custom markdown renderer cannot be added.
* **Markdown is never rendered** (highlighted source via `bat`). **PDF/video
  previews are image thumbnails** (first page / one frame) and need the kitty
  graphics protocol — Ghostty, kitty, WezTerm; sixel and iTerm2 fall back to
  ANSI blocks. **Mouse is wheel-scroll only**, unconditionally enabled upstream;
  clicks do nothing.
* The config is a read-only store symlink: superfile only writes `config.toml`
  when absent, so it never clobbers it — but never run `--fix-config-file`.
* `[open_with]` must be the last TOML table; keep it the only table in
  `settings`.
