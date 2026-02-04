{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.direnv;
in
{
  options.my.programs.direnv = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable direnv for automatic environment loading";
    };

    enableNixDirenv = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable nix-direnv integration for better Nix support";
    };

    hideEnvDiff = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Hide environment diff output when entering directories";
    };

    globalConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional global direnv configuration options";
      example = lib.literalExpression ''
        {
          warn_timeout = "5m";
          load_dotenv = true;
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv = {
        enable = cfg.enableNixDirenv;
        # Until https://github.com/nix-community/home-manager/pull/5773
        package = lib.mkIf (config.nix.package != null)
          (pkgs.nix-direnv.override { nix = config.nix.package; });
      };
      config.global = {
        hide_env_diff = cfg.hideEnvDiff;
      } // cfg.globalConfig;
    };
  };
}