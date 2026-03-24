{ lib, config, ... }:

let
  cfg = config.my.services.gitRepoSync;
in {
  config = lib.mkIf cfg.enable {
    home-manager.users.${cfg.user} = {
      systemd.user.startServices = lib.mkDefault "sd-switch";
    };
  };
}