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
  ];
}
