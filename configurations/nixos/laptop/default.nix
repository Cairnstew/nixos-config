{ config, flake, pkgs, lib,  ... }:

let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{

  nixos-unified.sshTarget = "seanc@laptop";

  imports = [
    ./configuration.nix

    self.nixosModules.default
    
    self.nixosModules.zerotier
    self.nixosModules.localsend
    self.nixosModules.freecad
    self.nixosModules.spotify
    self.nixosModules.rstudio
    self.nixosModules.gnome
  ];

  home-manager.users.${config.me.username}.my = { 
        programs = {
          cudatext.enable = true;
          firefox.enable = true;
          obsidian.enable = true;
          thunderbird = {
            enable = true;
            email = flake.config.me.email;
            username = flake.config.me.username;
          };
          vscode.enable = true;
          youtube-music.enable = true;

        };

        services = {
          udiskie.enable = true;
        };

      };
  
  services.openssh.enable = true;

}
