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
      description = "The gh package to use.";
    };

    tokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/github-token";
      description = ''
        Path to a file containing the GitHub token.
        The file's contents will be exported as GITHUB_TOKEN at shell startup.
        Compatible with agenix, sops-nix, or any secret manager that exposes a file path.
      '';
    };

    extensions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "dlvhdr/gh-dash" ];
      description = "GitHub CLI extensions (OWNER/REPO format).";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Config written to gh config.yml.";
    };

    hosts = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Host config (no auth tokens).";
    };
  };

  config = lib.mkIf cfg.enable {
    # Export token at runtime only when tokenFile is set
    programs.zsh.initContent = lib.mkIf (cfg.tokenFile != null) (lib.mkAfter ''
      if [ -f ${cfg.tokenFile} ]; then
        export GITHUB_TOKEN="$(cat ${cfg.tokenFile})"
      fi
    '');

    programs.bash.initExtra = lib.mkIf (cfg.tokenFile != null) (lib.mkAfter ''
      if [ -f ${cfg.tokenFile} ]; then
        export GITHUB_TOKEN="$(cat ${cfg.tokenFile})"
      fi
    '');

    home.packages = [ cfg.package ];

    programs.gh = {
      enable = true;
      settings = cfg.settings;
      hosts = cfg.hosts;
    };

    home.activation.installGhExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for ext in ${lib.concatStringsSep " " cfg.extensions}; do
        ${cfg.package}/bin/gh extension install "$ext" || true
      done
    '';
  };
}