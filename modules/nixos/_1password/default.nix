{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "${flake.config.me.username}" ];
  };
  security.polkit.enable = true;

  home-manager.users.${config.me.username} = {
    imports = [ ./home.nix ];
    my.programs.ssh-1password.enable = true;
  };
}