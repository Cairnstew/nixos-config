# VS Code

Visual Studio Code editor configuration with extensions and Continue AI integration.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.programs.vscode.enable` | `false` | Enable VS Code |
| `my.programs.vscode.server.enable` | `false` | Enable VS Code server (NixOS only) |
| `my.programs.vscode.extensions` | `[dracula, python, jupyter, nix, remote]` | Default extensions |
| `my.programs.vscode.additionalExtensions` | `[]` | Extra extensions to install |
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
