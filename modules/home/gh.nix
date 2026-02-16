{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.gh;
in
{
  options.my.programs.gh = {
    enable = lib.mkEnableOption "GitHub CLI (gh)";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.gh;
      defaultText = "pkgs.gh";
      description = "The gh package to use.";
    };

    extensions = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = [ pkgs.gh-eco ];
      description = ''
        GitHub CLI extensions to install.
        Each entry should be in the form "OWNER/REPO".
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      example = {
        git_protocol = "ssh";
        prompt = "enabled";
        editor = "vim";

        aliases = {
          co = "pr checkout";
          pv = "pr view";
        };
      };
      description = ''
        Configuration written to
        $XDG_CONFIG_HOME/gh/config.yml.
      '';
    };

    hosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrs);
      default = { };
      example = {
        "github.com" = {
          user = "userName";
        };
      };
      description = ''
        Host-specific configuration written to
        $XDG_CONFIG_HOME/gh/hosts.yml.

        Authentication tokens are not managed here.
        Use `gh auth login` to authenticate.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
    ];
    programs.gh = {
      enable = cfg.enable;
      extensions = cfg.extensions;
      hosts = cfg.hosts;
      settings = cfg.settings;


    };
  };
}
