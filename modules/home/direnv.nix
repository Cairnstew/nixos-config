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

    secretFiles = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          vars = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = {};
            description = "Map of env var names to secret file paths — exports file contents as value";
            example = lib.literalExpression ''
              {
                MY_API_TOKEN = config.age.secrets.my-api-token.path;
              }
            '';
          };
          paths = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = {};
            description = "Map of env var names to secret file paths — exports the path itself as value";
            example = lib.literalExpression ''
              {
                MY_PRIVATE_KEY_PATH = config.age.secrets.my-private-key.path;
              }
            '';
          };
          envFiles = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Paths to KEY=VALUE secret files to source directly";
            example = lib.literalExpression ''
              [ config.age.secrets.aws-labs-creds.path ]
            '';
          };
        };
      });
      default = {};
      description = ''
        Named secret files to generate under ~/.config/direnv/secrets/.
        Paths can be anything — agenix paths, absolute paths, etc.
      '';
      example = lib.literalExpression ''
        {
          aws-labs = {
            envFiles = [ config.age.secrets.aws-labs-creds.path ];
          };
          my-api = {
            vars = {
              MY_API_TOKEN = config.age.secrets.my-api-token.path;
            };
          };
          ssh-keys = {
            paths = {
              MY_PRIVATE_KEY_PATH = config.age.secrets.my-private-key.path;
            };
          };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv = {
        enable = cfg.enableNixDirenv;
        package = lib.mkIf (config.nix.package != null)
          (pkgs.nix-direnv.override { nix = config.nix.package; });
      };
      config.global = {
        hide_env_diff = cfg.hideEnvDiff;
      } // cfg.globalConfig;
    };

    home.file = lib.mapAttrs' (fileName: fileCfg: {
      name = ".config/direnv/secrets/${fileName}.sh";
      value.text = ''
        ${lib.concatStrings (lib.mapAttrsToList (envName: path: ''
          export ${envName}=$(cat ${path})
        '') fileCfg.vars)}
        ${lib.concatStrings (lib.mapAttrsToList (envName: path: ''
          export ${envName}=${path}
        '') fileCfg.paths)}
        ${lib.concatMapStrings (path: ''
          set -a
          source ${path}
          set +a
        '') fileCfg.envFiles}
      '';
    }) cfg.secretFiles;
  };
}