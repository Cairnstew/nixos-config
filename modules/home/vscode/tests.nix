{ config, lib, ... }:
let
  cfg = config.my.programs.vscode;
in
{
  # ── L0: Nix assertions ────────────────────────────────────────────────────
  assertions = [
    {
      assertion = !(cfg.continue.enable && cfg.continue.models == [ ]);
      message = "my.programs.vscode.continue.models must not be empty when Continue is enabled";
    }
    {
      assertion = !(cfg.enable && cfg.theme.enable) || cfg.theme.baseTheme != "";
      message = "vscode theme: baseTheme must not be empty.";
    }
    {
      assertion =
        !(cfg.enable && cfg.theme.enable)
        || (cfg.theme.settings."workbench.colorCustomizations" or { }) ? "editor.background";
      message = "vscode theme: settings are missing the workbench colour customizations.";
    }
    {
      assertion = builtins.all
        (
          kb: (kb ? key) && (kb ? command)
        )
        cfg.keybindings;
      message = "my.programs.vscode.keybindings: every entry needs at least `key` and `command`.";
    }
    {
      assertion = !(cfg.enable && cfg.mcp.enable) || config.programs.mcp.enable;
      message = ''
        my.programs.vscode.mcp.enable forwards programs.mcp.servers, but
        programs.mcp.enable is false. Enable it (NixOS hosts do this in
        modules/nixos/homeManager/config.nix) or set
        my.programs.vscode.mcp.enable = false.
      '';
    }
  ];
}
