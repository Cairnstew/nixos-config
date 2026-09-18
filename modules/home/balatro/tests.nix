{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.balatro;
in
{
  # ── L0: Nix assertions ────────────────────────────────────────────────────
  assertions = [
    {
      assertion = cfg.multiplayer.enable -> cfg.enable;
      message = ''
        my.programs.balatro.multiplayer.enable requires my.programs.balatro.enable to be true.
      '';
    }
  ];
}
