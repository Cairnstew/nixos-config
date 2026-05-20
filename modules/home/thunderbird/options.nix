{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.thunderbird;
in
{
  options.my.programs.thunderbird = {
    enable = lib.mkEnableOption "Mozilla Thunderbird email client";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.thunderbird;
      defaultText = lib.literalExpression "pkgs.thunderbird";
      description = "The Thunderbird package to install";
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = config.home.username;
      defaultText = lib.literalExpression "config.home.username";
      description = "Username for Thunderbird profile";
    };

    email = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Default email address for Thunderbird configuration.
        If empty, no email account will be pre-configured.
      '';
      example = "user@example.com";
    };

    profileName = lib.mkOption {
      type = lib.types.str;
      default = "default";
      description = "Name of the Thunderbird profile to create/use";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = ''
        Thunderbird preferences to set in the profile.
        See https://wiki.mozilla.org/Thunderbird/Data_collection for options.
      '';
      example = lib.literalExpression ''
        {
          "general.useragent.locale" = "en-US";
          "mailnews.default_news_view_flags" = 1;
        }
      '';
    };
  };
}
