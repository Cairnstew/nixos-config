{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
  
in
{

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    # Certain features, including CLI integration and system authentication support,
    # require enabling PolKit integration on some desktop environments (e.g. Plasma).
    polkitPolicyOwners = [ "${flake.config.me.username}" ];
  };
  security.polkit.enable = true;


  home-manager.users.${config.me.username}.my.programs = { 
    ssh-1password.enable = true;
  };



}
