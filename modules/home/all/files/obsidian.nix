{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{

  programs.obsidian = {
    enable = true;
    defaultSettings = {
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
  };
}
