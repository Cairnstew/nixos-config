# VS Code

Visual Studio Code editor configuration with palette-derived theming, extensions,
Nix language support and Continue AI integration.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.vscode.enable` | `false` | Enable VS Code |
| `my.programs.vscode.server.enable` | `false` | Enable VS Code server (NixOS only) |
| `my.programs.vscode.package` | `null` | VS Code build to install (`null` = `pkgs.vscode`); not for forks |
| `my.programs.vscode.extensions` | `[python, jupyter, nix-ide, direnv, remote]` | Default extensions |
| `my.programs.vscode.theme` | generated | Palette-derived workbench + token colours (`enable`, `overrides`, `baseTheme`) |
| `my.programs.vscode.additionalExtensions` | `[]` | Extra extensions to install |
| `my.programs.vscode.userSettings` | _(see options.nix)_ | VS Code user settings (settings.json) |
| `my.programs.vscode.keybindings` | `[]` | Keybindings (`keybindings.json`); entries need `key` + `command` |
| `my.programs.vscode.globalSnippets` | `{}` | Global user snippets |
| `my.programs.vscode.languageSnippets` | `{}` | Per-language user snippets |
| `my.programs.vscode.mcp.enable` | `true` | Forward `programs.mcp.servers` into `mcp.json` |
| `my.programs.vscode.continue.enable` | `false` | Enable Continue AI assistant |
| `my.programs.vscode.continue.ollamaHost` | `http://127.0.0.1:11434` | Ollama API URL |
| `my.programs.vscode.continue.models` | `[]` | Ollama models for Continue |
| `my.programs.vscode.continue.extraConfig` | `{}` | Extra Continue config |

## Usage Example

```nix
my.programs.vscode = {
  enable = true;
  server.enable = true;  # For Remote-SSH/WSL
  additionalExtensions = with pkgs.vscode-extensions; [
    rust-lang.rust-analyzer
  ];
  keybindings = [
    { key = "ctrl+k"; command = "workbench.action.files.saveAll"; when = "editorFocus"; }
  ];
  continue = {
    enable = true;
    models = [ "llama3.2" "mistral" ];
  };
};
```

## Notes

- `server.enable` requires the `nixosModules.vscode-server` NixOS module to have any effect.
- On standalone Home Manager, `server.enable` is a no-op.
- Continue config is written to `~/.continue/config.yaml`.
- The default settings point `jnoortheen.nix-ide` at `nixd` and `nixpkgs-fmt`
  (absolute store paths), so Nix language support works without either tool on
  the user's `PATH`.
- `mcp.enable` requires `programs.mcp.enable = true`; the NixOS host config
  enables it and declares the shared servers (`nixos`, `fetch`, `filesystem`, …).
- The `mkhl.direnv` extension loads each workspace's `.envrc` (this repo's uses
  `use flake`, so the devShell). Settings pin the `direnv` executable by store
  path and set `direnv.restart.automatic`, so the extension host reloads once
  the environment changes. Each project still needs a one-time `direnv allow`.
- Update checks are disabled by `mkDefault` — Nix owns the VS Code build and its
  extensions. Override `programs.vscode.profiles.default.enableUpdateCheck` to
  re-enable the notifications.
