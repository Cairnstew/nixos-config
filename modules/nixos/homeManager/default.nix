{ flake, pkgs, lib, config, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{

    users.users.${flake.config.me.username}.isNormalUser = lib.mkDefault true;
    home-manager.backupFileExtension = "backup";
    home-manager.sharedModules = builtins.attrValues self.homeModules;
    home-manager.users.${flake.config.me.username}.my = { 
      programs = {
        ssh-1password.enable = true;
        bash.enable = true;
        direnv.enable = true;
        gh = {
          enable = true;

          tokenFile = config.age.secrets."github-token".path;

          settings = {
            git_protocol = "ssh";
          };

          hosts = {
            "github.com" = {
              user = flake.config.me.github_username;
              git_protocol = "ssh";
            };
          };
        };
        ghostty.enable = true;
        just.enable = true;
        obsidian = {
          repo = {
            enable = true;
            url = "https://github.com/Cairnstew/Cairns-Notes";
            tokenFile = config.age.secrets."obsidian-git-token".path;
          };
        };
        yazi.enable = true;
        zsh.enable = true;
      };
    };
}
