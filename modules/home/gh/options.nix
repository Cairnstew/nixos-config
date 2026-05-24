{ lib, pkgs, ... }:

let
  types = lib.types;
in
{
  options.my.programs.gh = {
    enable = lib.mkEnableOption "GitHub CLI (gh)";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.gh;
      defaultText = lib.literalExpression "pkgs.gh";
      description = "The gh package to use.";
    };

    tokenFile = lib.mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/agenix/github-token";
      description = ''
        Path to a file containing a GitHub PAT.
        The file's contents will be exported as GITHUB_TOKEN at shell startup,
        making it available to gh, github-actions-cleanup, and other tools.
        Compatible with agenix, sops-nix, or any secret manager.
      '';
    };

    extensions = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "dlvhdr/gh-dash" ];
      description = "GitHub CLI extensions to install (OWNER/REPO format).";
    };

    settings = lib.mkOption {
      type = types.attrs;
      default = { };
      description = "Config written to gh config.yml.";
    };

    hosts = lib.mkOption {
      type = types.attrsOf types.attrs;
      default = { };
      description = "Host config entries (no auth tokens).";
    };
  };
}
