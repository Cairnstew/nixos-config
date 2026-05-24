{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.steam;
in
{
  # ── L0: Nix assertions ────────────────────────────────────────────────────
  assertions = [
    {
      assertion = !cfg.enable -> (cfg.extraCompatPaths == null || lib.hasPrefix "$HOME/" cfg.extraCompatPaths || lib.hasPrefix "/" cfg.extraCompatPaths);
      message = ''
        my.programs.steam.extraCompatPaths must be an absolute path or start with $HOME/.
        Got: ${builtins.toString cfg.extraCompatPaths}
      '';
    }
  ];
}
