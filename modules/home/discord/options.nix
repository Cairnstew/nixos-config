{ lib, pkgs, ... }:

let
  types = lib.types;
in
{
  options.my.programs.discord = {
    enable = lib.mkEnableOption "Discord desktop client";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.discord;
      defaultText = lib.literalExpression "pkgs.discord";
      description = "The Discord package to use.";
    };

    tui = {
      enable = lib.mkEnableOption "Endcord TUI client";

      profile = lib.mkOption {
        type = types.attrsOf (types.submodule {
          options = {
            enable = lib.mkEnableOption "this Endcord profile";
            tokenFile = lib.mkOption {
              type = types.nullOr types.path;
              default = null;
              description = ''
                Path to a file containing the Discord token for this profile.
                Use with config.age.secrets."<name>".path.
                On first activation, writes the token to Endcord's profiles.json.
              '';
            };
          };
        });
        default = { };
        description = "Endcord profiles to auto-configure. The attribute name is the profile name.";
      };
    };

    autostart = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Automatically start Discord/Endcord on login.";
    };

    extraPackages = lib.mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Extra packages or plugins to include with Discord.";
    };

    theme = lib.mkOption {
      type = types.str;
      default = "dark";
      description = "Discord theme (if you have a theme loader installed).";
    };
  };
}
