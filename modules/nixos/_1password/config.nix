{ config, lib, flake, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.programs._1password;
in
{
  config = mkIf cfg.enable {
    programs._1password.enable = true;
    programs._1password-gui = {
      enable = true;
      polkitPolicyOwners = [ "${flake.config.me.username}" ];
    };
    security.polkit.enable = true;

    home-manager.users.${flake.config.me.username} = {
      imports = [ ./home.nix ];
      my.programs.ssh-1password.enable = true;
    };
  };
}
