{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{
    users.users.${config.me.username}.isNormalUser = lib.mkDefault true;
    home-manager.backupFileExtension = "backup";
    home-manager.sharedModules = builtins.attrValues self.homeModules;
    home-manager.users.${config.me.username}.my.programs = { 
      ssh-1password.enable = true;
      bash.enable = true;
      direnv.enable = true;
      gh = {
        enable = true;
        settings = {
          git_protocol = "ssh";
        };
      };
      ghostty.enable = true;
      just.enable = true;
      yazi.enable = true;
      zsh.enable = true;
    };
}