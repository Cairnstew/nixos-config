{ config, lib, ... }:
let
  cfg = config.my.programs.steam;
in
{
  assertions = [
    {
      assertion =
        !cfg.enable
        || cfg.extraCompatPaths == null
        || lib.hasPrefix "/" cfg.extraCompatPaths
        || lib.hasPrefix "$HOME/" cfg.extraCompatPaths;
      message = ''
        my.programs.steam.extraCompatPaths must be an absolute path or start with $HOME/.
        Got: ${builtins.toString cfg.extraCompatPaths}
      '';
    }
  ];
}
