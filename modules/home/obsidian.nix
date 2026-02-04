{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.obsidian;
in
{
  options.my.programs.obsidian = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Obsidian with custom configuration";
    };

    defaultSettings = lib.mkOption {
      type = lib.types.attrs;
      default = {
        app = {
          promptDelete = false;
          alwaysUpdateLinks = true;
          attachmentFolderPath = "Images";
        };
        appearance = {
          cssTheme = "AnuPpuccin";
        };
        communityPlugins = [
          "obsidian-shellcommands"
          "buttons"
          "obsidian42-brat"
          "obsidian-git"
        ];
      };
      description = "Default settings for Obsidian";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.obsidian = {
      enable = true;
      defaultSettings = cfg.defaultSettings;
    };
  };
}