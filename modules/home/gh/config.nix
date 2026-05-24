{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.gh;
in
{
  config = lib.mkIf cfg.enable {

    # ── Auto-detect token from agenix secrets catalog ──────────────────────
    # Defaults to the conventional agenix path (/run/agenix/github-token).
    # The activation script checks the file at runtime, so it's safe if the
    # file doesn't exist yet (e.g. agenix not configured).
    my.programs.gh.tokenFile = lib.mkDefault "/run/agenix/github-token";

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
    # Tries 'gh auth login --with-token' to properly authenticate gh.
    # Requires PAT with repo + read:org scopes. If it fails (e.g. missing
    # read:org), GITHUB_TOKEN env var is still exported for CLI tools.
    home.activation.ghAuthLogin = lib.mkIf (cfg.tokenFile != null) (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -f "${cfg.tokenFile}" ]; then
        token=$(cat "${cfg.tokenFile}" | tr -d '\n')
        if [ -n "$token" ]; then
          if echo "$token" | ${cfg.package}/bin/gh auth login --with-token 2>/dev/null; then
            echo "[gh] Authenticated successfully"
          else
            echo "[gh] Token present but gh auth login failed (token needs repo + read:org scopes)"
          fi
        fi
      fi
    '');
  };
}
