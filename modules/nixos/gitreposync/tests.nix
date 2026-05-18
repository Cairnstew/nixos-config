{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mapAttrsToList hasPrefix;
  cfg = config.my.services.gitRepoSync;
in {
  config = mkIf cfg.enable {
    # ── L0: Nix assertions ────────────────────────────────────────────────────
    assertions =
      mapAttrsToList (name: repo: {
        assertion = repo.agenix.enable -> (hasPrefix "https://" repo.url);
        message   = "git-repo-sync: repo '${name}' uses agenix token injection "
                  + "but its URL is not https://. Token injection only works with HTTPS remotes.";
      }) cfg.repos
      ++ mapAttrsToList (name: repo: {
        assertion = repo.cloneBare -> !repo.autoPull;
        message   = "git-repo-sync: repo '${name}' is a bare clone — set autoPull = false "
                  + "(bare repos have no working tree to merge into).";
      }) cfg.repos;

    # ── L2: Smoke-test oneshot ───────────────────────────────────────────────
    systemd.user.services."git-repo-sync-smoke-test" = {
      description = "git repo sync smoke test";
      serviceConfig = {
        Type = "oneshot";
      };
      script =
        let
          git = "${pkgs.git}/bin/git";
          checkRepo = name: repo: ''
            echo "[smoke-test] Checking ${name} at ${repo.path} ..."
            if [ ! -d "${repo.path}/.git" ]; then
              echo "[smoke-test] FAIL: ${name} is not a git repo (missing .git)" >&2
              FAILED=1
            else
              if ! ${git} -C "${repo.path}" rev-parse --git-dir > /dev/null 2>&1; then
                echo "[smoke-test] FAIL: ${name} is not a valid git repository" >&2
                FAILED=1
              else
                echo "[smoke-test] PASS: ${name} is a valid git repo"
              fi
            fi
          '';
        in ''
          set -uo pipefail
          FAILED=0

          ${lib.concatStrings (mapAttrsToList checkRepo cfg.repos)}

          if [ "$FAILED" = "0" ]; then
            echo "[smoke-test] ALL CHECKS PASSED"
          else
            echo "[smoke-test] SOME CHECKS FAILED" >&2
            exit 1
          fi
        '';
    };
  };
}
