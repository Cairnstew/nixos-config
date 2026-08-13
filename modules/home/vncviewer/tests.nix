{ config, lib, ... }:

let
  cfg = config.my.programs.vncviewer;
in
{
  # ── L0: Nix assertions ────────────────────────────────────────────────────
  assertions = [
    {
      assertion = !cfg.enable || lib.all (c: c.host != "") (lib.attrValues cfg.connections);
      message = "my.programs.vncviewer.connections.<name>.host must not be empty.";
    }
    {
      assertion = !cfg.enable || !lib.any (c: c.scale != null && (c.scale < 10 || c.scale > 400)) (lib.attrValues cfg.connections);
      message = "my.programs.vncviewer.connections.<name>.scale must be between 10 and 400 (percentage).";
    }
  ];
}
