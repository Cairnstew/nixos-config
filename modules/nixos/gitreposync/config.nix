{ config, lib, ... }:

let
  inherit (lib) mkIf mapAttrsToList hasPrefix;
  cfg = config.my.services.gitRepoSync;
in
{
  config = mkIf cfg.enable {
    users.users.${cfg.user} = {
      linger = lib.mkDefault true;
    };
  };
}
