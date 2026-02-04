{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{
    users.users.${config.me.username}.isNormalUser = lib.mkDefault true;
    home-manager.backupFileExtension = "backup";
    home-manager.sharedModules = [
      self.homeModules.default
      self.homeModules._1password
      self.homeModules.bash
      self.homeModules.cudatext
      self.homeModules.direnv
      self.homeModules.firefox
      self.homeModules.ghostty
      self.homeModules.gnome
      self.homeModules.gotty
      self.homeModules.just
      self.homeModules.obsidian
      self.homeModules.thunderbird
      self.homeModules.udiskie
      self.homeModules.vscode
      self.homeModules.yazi
      self.homeModules.youtube-music
      self.homeModules.zsh
    ];
    home-manager.users.${config.me.username}.my.programs = { 
      ssh-1password.enable = true;
      bash.enable = true;
      direnv.enable = true;
      ghostty.enable = true;
      just.enable = true;
      yazi.enable = true;
      zsh.enable = true;
    };
}