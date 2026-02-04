{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.ssh-1password;
in
{
  options.my.programs.ssh-1password = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable SSH with 1Password agent integration";
    };

    install1PasswordCli = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install 1Password CLI";
    };

    enableDefaultConfig = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable SSH default configuration";
    };

    additionalMatchBlocks = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional SSH match blocks to configure";
      example = lib.literalExpression ''
        {
          "pureintent" = {
            forwardAgent = true;
          };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mkIf cfg.install1PasswordCli [ pkgs._1password-cli ];
    
    programs.ssh = {
      enable = true;
      enableDefaultConfig = cfg.enableDefaultConfig;
      matchBlocks = {
        "*" = {
          extraOptions = {
            # Configure SSH to use 1Password agent
            IdentityAgent =
              if pkgs.stdenv.isDarwin
              then "~/Library/Group\\ Containers/2BUA8C4S2C.com.1password/t/agent.sock"
              else "~/.1password/agent.sock";
          };
        };
      } // cfg.additionalMatchBlocks;
    };
  };
}