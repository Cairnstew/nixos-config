{ config, lib, ... }:

let
  cfg = config.my.programs.discord;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.theme != "";
        message = "my.programs.discord.theme must not be empty.";
      }
    ];
  };
}
