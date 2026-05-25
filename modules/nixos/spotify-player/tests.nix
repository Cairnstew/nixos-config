{ config, lib, ... }:
let
  cfg = config.my.programs.spotify;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.clientIdFile == null || lib.stringLength (builtins.toString cfg.clientIdFile) > 0;
        message = "my.programs.spotify.clientIdFile must not be empty when set.";
      }
    ];
  };
}
