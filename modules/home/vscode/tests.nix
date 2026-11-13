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
  ];
}
