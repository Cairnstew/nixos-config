{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.gh;
in
{
  config = lib.mkIf cfg.enable {

    # ── Auto-detect token from agenix secrets catalog ──────────────────────
    # If the secrets catalog has "github.token" (decrypted to /run/agenix/github-token),
    # wire it as tokenFile automatically so per-host boilerplate is unnecessary.
    # Uses tryEval to be safe in standalone Home Manager where age.secrets may not exist.
    my.programs.gh.tokenFile = lib.mkDefault (
      let
        hasSecret = builtins.tryEval (config.age.secrets ? "github-token");
      in
      if hasSecret.success && hasSecret.value then
        config.age.secrets.github-token.path
      else
        null
    );

    # ── Export GITHUB_TOKEN at shell startup ────────────────────────────────
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

    # ── Packages ───────────────────────────────────────────────────────────
    home.packages = [ cfg.package ];

    # ── gh CLI config ──────────────────────────────────────────────────────
    programs.gh = {
      enable = true;
      settings = cfg.settings;
      hosts = cfg.hosts;
    };

    # ── Extensions ─────────────────────────────────────────────────────────
    home.activation.installGhExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for ext in ${lib.concatStringsSep " " cfg.extensions}; do
        ${cfg.package}/bin/gh extension install "$ext" || true
      done
    '';

    # ── Auth login via token file ───────────────────────────────────────────
    # This properly authenticates gh so `gh auth status` shows the user.
    # Runs after writeBoundary so the config directory exists.
    home.activation.ghAuthLogin = lib.mkIf (cfg.tokenFile != null) (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -f "${cfg.tokenFile}" ]; then
        token=$(cat "${cfg.tokenFile}" | tr -d '\n')
        if [ -n "$token" ]; then
          echo "$token" | ${cfg.package}/bin/gh auth login --with-token 2>/dev/null || true
        fi
      fi
    '');
  };
}
