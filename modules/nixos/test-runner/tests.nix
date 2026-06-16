{ config, lib, ... }:
let
  cfg = config.my.testing;
in
{
  # ── L0: Nix assertions ──────────────────────────────────────────────────────
  assertions = [
    {
      assertion = !cfg.enable || cfg.categories != [ ];
      message = "my.testing.categories must be non-empty when my.testing.enable = true. Set at least one of \"smoke\" or \"health\".";
    }
  ];
}
