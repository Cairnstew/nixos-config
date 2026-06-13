{ config, lib, ... }:
let
  cfg = config.my.programs.steam;
  hasGames = cfg.games != { };
in
{

  assertions =
    [
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
      {
        assertion = !hasGames || cfg.enable;
        message = ''
          my.programs.steam.games requires my.programs.steam.enable to be true.
        '';
      }
    ]
    ++ lib.optionals (hasGames && cfg.enable) (lib.mapAttrsToList (name: game: {
      assertion = game.appId != "";
      message = "my.programs.steam.games.${name}.appId must not be empty.";
    }) cfg.games);
}
