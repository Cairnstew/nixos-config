{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.firefox;
in
{
  options.my.programs.firefox = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Firefox with custom configuration";
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = config.home.username;
      description = "Username for Firefox profile";
    };

    bookmarks = lib.mkOption {
      type = lib.types.listOf (
        lib.types.either lib.types.attrs lib.types.str
      );
      default = [
        {
          name = "wikipedia";
          tags = [ "wiki" ];
          keyword = "wiki";
          url = "https://en.wikipedia.org/wiki/Special:Search?search=%s&amp;go=Go";
        }
        {
          name = "kernel.org";
          url = "https://www.kernel.org";
        }
        "separator"
        {
          name = "Nix sites";
          toolbar = true;
          bookmarks = [
            {
              name = "homepage";
              url = "https://nixos.org/";
            }
            {
              name = "wiki";
              tags = [ "wiki" "nix" ];
              url = "https://wiki.nixos.org/";
            }
          ];
        }
      ];
      description = "Firefox bookmarks configuration";
      example = lib.literalExpression ''
        [
          {
            name = "Example";
            url = "https://example.com";
          }
        ]
      '';
    };

    forceBookmarks = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Force bookmark configuration (overwrite existing)";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.firefox = {
      enable = true;
      profiles.${cfg.username} = {
        isDefault = true;
        bookmarks = {
          force = cfg.forceBookmarks;
          settings = cfg.bookmarks;
        };
      };
    };
  };
}