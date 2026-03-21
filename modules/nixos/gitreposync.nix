{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.my.services.gitRepoSync;

  # ── Per-branch pull logic, driven by conflictStrategy ──────────────────────
  mkPullLogic = name: repo: branch:
    let
      repoPath = repo.path;
      ref      = "${repo.remote}/${branch}";
      stashMsg = "git-repo-sync-stash-${name}-${branch}";
    in
    if repo.conflictStrategy == "ff-only" then ''
      ${git} -C "${repoPath}" merge --ff-only "${ref}" 2>/dev/null \
        || echo "[git-repo-sync] ${name}/${branch}: SKIP — fast-forward not possible (local commits or dirty tree)."
    ''

    else if repo.conflictStrategy == "rebase" then ''
      if ! ${git} -C "${repoPath}" rebase "${ref}" 2>/tmp/git-sync-err-${name}; then
        echo "[git-repo-sync] ${name}/${branch}: rebase CONFLICT — aborting and leaving branch unchanged." >&2
        cat /tmp/git-sync-err-${name} >&2
        ${git} -C "${repoPath}" rebase --abort 2>/dev/null || true
      fi
      rm -f /tmp/git-sync-err-${name}
    ''

    else if repo.conflictStrategy == "reset-hard" then ''
      echo "[git-repo-sync] ${name}/${branch}: resetting to ${ref} (destructive — local commits discarded)."
      ${git} -C "${repoPath}" reset --hard "${ref}"
    ''

    else if repo.conflictStrategy == "stash-and-pull" then ''
      DIRTY=$(${git} -C "${repoPath}" status --porcelain 2>/dev/null)
      STASHED=0
      if [ -n "$DIRTY" ]; then
        echo "[git-repo-sync] ${name}/${branch}: stashing local changes before pull."
        ${git} -C "${repoPath}" stash push --include-untracked -m "${stashMsg}" \
          && STASHED=1 \
          || echo "[git-repo-sync] ${name}/${branch}: SKIP — stash failed, leaving branch unchanged."
      fi

      if ! ${git} -C "${repoPath}" merge --ff-only "${ref}" 2>/tmp/git-sync-err-${name}; then
        echo "[git-repo-sync] ${name}/${branch}: fast-forward failed after stash (diverged history?)." >&2
        cat /tmp/git-sync-err-${name} >&2
      fi
      rm -f /tmp/git-sync-err-${name}

      if [ "$STASHED" = "1" ]; then
        STASH_REF=$(${git} -C "${repoPath}" stash list --format="%gd %s" \
          | awk '/${stashMsg}/ {print $1; exit}')
        if [ -n "$STASH_REF" ]; then
          echo "[git-repo-sync] ${name}/${branch}: restoring stashed changes."
          ${git} -C "${repoPath}" stash pop "$STASH_REF" 2>/tmp/git-sync-pop-err-${name} \
            || {
              echo "[git-repo-sync] ${name}/${branch}: WARNING — stash pop conflicted. Changes preserved in stash entry $STASH_REF." >&2
              cat /tmp/git-sync-pop-err-${name} >&2
            }
          rm -f /tmp/git-sync-pop-err-${name}
        fi
      fi
    ''

    else abort "git-repo-sync: unknown conflictStrategy '${repo.conflictStrategy}'";

  # ── Fetch + pull block for one repo ────────────────────────────────────────
  mkBranchSync = name: repo:
    let
      fetchArgs = concatStringsSep " " (
        optional repo.fetchPrune "--prune"
        ++ optional (repo.fetchDepth != null) "--depth ${toString repo.fetchDepth}"
        ++ map (b: "--refmap '+refs/heads/${b}:refs/remotes/${repo.remote}/${b}'") repo.branches
      );

      guardedPull = branch: ''
        CURRENT=$(${git} -C "${repo.path}" symbolic-ref --short HEAD 2>/dev/null || true)
        if [ "$CURRENT" = "${branch}" ]; then
          ${mkPullLogic name repo branch}
        else
          echo "[git-repo-sync] ${name}: not on '${branch}' (currently '$CURRENT'), skipping pull."
        fi
      '';

      guardedPullCurrent = ''
        CURRENT=$(${git} -C "${repo.path}" symbolic-ref --short HEAD 2>/dev/null || true)
        if [ -n "$CURRENT" ]; then
          ${mkPullLogic name repo "$CURRENT"}
        fi
      '';
    in
    if repo.branches == [] then ''
      ${git} -C "${repo.path}" fetch ${repo.remote} ${fetchArgs}
      ${optionalString repo.autoPull guardedPullCurrent}
    ''
    else concatMapStrings (branch: ''
      ${git} -C "${repo.path}" fetch ${repo.remote} ${fetchArgs} "${branch}:${branch}" 2>/dev/null \
        || ${git} -C "${repo.path}" fetch ${repo.remote} ${fetchArgs}
      ${optionalString repo.autoPull (guardedPull branch)}
    '') repo.branches;

  # ── Shell script for one repo ──────────────────────────────────────────────
  git  = "${pkgs.git}/bin/git";

  mkSyncScript = name: repo:
    let
      tokenEnv = optionalString repo.agenix.enable ''
        GITHUB_TOKEN_FILE="${repo.agenix.secretPath}"
        if [ ! -f "$GITHUB_TOKEN_FILE" ]; then
          echo "[git-repo-sync] WARNING: agenix secret not found at $GITHUB_TOKEN_FILE" >&2
        else
          GITHUB_TOKEN=$(cat "$GITHUB_TOKEN_FILE" | tr -d '[:space:]')
          AUTHED_URL=$(echo "${repo.url}" | sed "s|https://|https://${repo.agenix.tokenUser}:$GITHUB_TOKEN@|")
        fi
      '';

      cloneUrl = if repo.agenix.enable
        then "\${AUTHED_URL:-${repo.url}}"
        else repo.url;

    in pkgs.writeShellScript "git-repo-sync-${name}" ''
      set -euo pipefail

      GITHUB_TOKEN=""
      AUTHED_URL=""

      ${tokenEnv}

      # ── Clone if missing ──────────────────────────────────────────────────
      if [ ! -d "${repo.path}/.git" ]; then
        echo "[git-repo-sync] Cloning ${name} into ${repo.path} ..."
        mkdir -p "${repo.path}"

        CLONE_ARGS=""
        ${optionalString (repo.cloneBranch != null)
          ''CLONE_ARGS="$CLONE_ARGS --branch ${repo.cloneBranch}"''}
        ${optionalString (repo.fetchDepth != null)
          ''CLONE_ARGS="$CLONE_ARGS --depth ${toString repo.fetchDepth}"''}
        ${optionalString repo.cloneBare
          ''CLONE_ARGS="$CLONE_ARGS --bare"''}

        ${git} clone $CLONE_ARGS "${cloneUrl}" "${repo.path}"
        echo "[git-repo-sync] ${name}: clone complete."
      else
        # ── Fetch / pull ────────────────────────────────────────────────────
        echo "[git-repo-sync] Syncing ${name} (strategy: ${repo.conflictStrategy}) ..."

        ${optionalString repo.agenix.enable ''
          if [ -n "$GITHUB_TOKEN" ]; then
            ORIG_URL=$(${git} -C "${repo.path}" remote get-url ${repo.remote})
            ${git} -C "${repo.path}" remote set-url ${repo.remote} "$AUTHED_URL"
            trap '${git} -C "${repo.path}" remote set-url ${repo.remote} "$ORIG_URL"' EXIT
          fi
        ''}

        ${mkBranchSync name repo}

        echo "[git-repo-sync] ${name}: sync complete."
      fi
    '';

  # ── systemd units ──────────────────────────────────────────────────────────
  mkService = name: repo: {
    "git-repo-sync-${name}" = {
      description = "git repo sync: ${name}";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = repo.user;
        ExecStart = "${mkSyncScript name repo}";
        Environment = [
          "HOME=${repo.homeDir}"
          "GIT_TERMINAL_PROMPT=0"
          "PATH=${lib.makeBinPath [ pkgs.git pkgs.gnused pkgs.gawk pkgs.coreutils ]}"
        ];
      };
    };
  };

  mkTimer = name: repo: {
    "git-repo-sync-${name}" = {
      description = "git repo sync timer: ${name}";
      timerConfig = {
        OnBootSec = repo.onBootDelaySec;
        OnUnitActiveSec = repo.interval;
        Persistent = repo.timerPersistent;
      };
      wantedBy = [ "timers.target" ];
    };
  };

  # ── Per-repo option declarations ───────────────────────────────────────────
  repoOpts = { name, ... }: {
    options = {
      user = mkOption {
        type = types.str;
        description = "User to run the sync service as.";
        example = "alice";
      };

      homeDir = mkOption {
        type = types.str;
        description = "Home directory of the user (used to set HOME in the service environment).";
        example = "/home/alice";
      };

      url = mkOption {
        type = types.str;
        description = "Remote URL of the repository (https or ssh).";
        example = "https://github.com/your-org/your-repo.git";
      };

      path = mkOption {
        type = types.str;
        description = "Absolute path where the repo should live on disk.";
        example = "/home/alice/projects/my-repo";
      };

      remote = mkOption {
        type = types.str;
        default = "origin";
        description = "Name of the git remote to fetch from.";
      };

      branches = mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          Specific branches to track. If empty, fetches all refs and applies
          the pull strategy to whatever branch is currently checked out.
        '';
        example = [ "main" "develop" ];
      };

      cloneBranch = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Branch to check out on initial clone. Defaults to the remote HEAD.";
      };

      cloneBare = mkOption {
        type = types.bool;
        default = false;
        description = "Clone as a bare repository (--bare). Useful for mirrors.";
      };

      autoPull = mkOption {
        type = types.bool;
        default = true;
        description = ''
          After fetching, apply conflictStrategy to integrate remote changes.
          Set false to fetch only (remote-tracking refs update, working tree untouched).
        '';
      };

      conflictStrategy = mkOption {
        type = types.enum [ "ff-only" "rebase" "reset-hard" "stash-and-pull" ];
        default = "ff-only";
        description = ''
          How to handle integration when a fast-forward merge is not possible.

            ff-only        Safe default. Skips the pull and logs a warning.
                           Never rewrites history or discards work. Best when
                           you want visibility into divergence without automation.

            rebase         Rebases local commits on top of the remote branch.
                           Keeps history linear. On conflict the rebase is
                           aborted cleanly and the branch is left unchanged.

            reset-hard     Discards all local commits and resets to the remote
                           branch exactly. Treats the repo as a read-only mirror.
                           DESTRUCTIVE: any unpushed work is permanently lost.

            stash-and-pull Stashes local modifications (staged + unstaged),
                           fast-forward merges, then pops the stash. If the pop
                           conflicts the stash entry is preserved with a clear
                           warning so you can resolve manually. Good for repos
                           where you make occasional local tweaks but mostly
                           follow upstream.
        '';
        example = "stash-and-pull";
      };

      fetchPrune = mkOption {
        type = types.bool;
        default = true;
        description = "Pass --prune to git fetch to remove stale remote-tracking refs.";
      };

      fetchDepth = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Shallow clone/fetch depth. null = full history.";
        example = 1;
      };

      interval = mkOption {
        type = types.str;
        default = "15m";
        description = "How often to sync (systemd time span, e.g. '5m', '1h').";
        example = "30m";
      };

      onBootDelaySec = mkOption {
        type = types.str;
        default = "30s";
        description = "Delay after boot before the first sync fires.";
      };

      timerPersistent = mkOption {
        type = types.bool;
        default = true;
        description = "Trigger missed runs on next boot.";
      };

      agenix = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable agenix-based GitHub fine-grained token injection.
            Token is read from disk at runtime — never stored in the Nix store.
          '';
        };

        secretPath = mkOption {
          type = types.str;
          default = "/run/agenix/github-token-${name}";
          description = "Path to the agenix-decrypted file containing the raw GitHub token.";
          example = "/run/agenix/github-token-my-repo";
        };

        tokenUser = mkOption {
          type = types.str;
          default = "oauth2";
          description = ''
            Username injected into the https URL alongside the token.
            "oauth2" and "x-access-token" are conventional GitHub choices.
          '';
        };
      };
    };
  };

in {
  # ── Module interface ────────────────────────────────────────────────────────
  options.my.services.gitRepoSync = {
    enable = mkEnableOption "git repository sync service" // { default = false; };

    repos = mkOption {
      type = types.attrsOf (types.submodule repoOpts);
      default = {};
      description = "Attribute set of repositories to keep synced.";
      example = literalExpression ''
        {
          dotfiles = {
            url              = "https://github.com/alice/dotfiles.git";
            path             = "/home/alice/.dotfiles";
            interval         = "1h";
            conflictStrategy = "ff-only";
          };

          notes = {
            url              = "https://github.com/alice/notes.git";
            path             = "/home/alice/notes";
            interval         = "10m";
            conflictStrategy = "stash-and-pull";
            agenix.enable     = true;
            agenix.secretPath = "/run/agenix/github-notes-token";
          };

          infra-mirror = {
            url              = "https://github.com/myorg/infra.git";
            path             = "/srv/mirrors/infra";
            interval         = "5m";
            conflictStrategy = "reset-hard";
            agenix.enable     = true;
            agenix.secretPath = "/run/agenix/github-infra-token";
          };
        }
      '';
    };
  };

  # ── Implementation ──────────────────────────────────────────────────────────
  config = mkIf cfg.enable {
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

    systemd.user.services = mkMerge (mapAttrsToList mkService cfg.repos);
    systemd.user.timers   = mkMerge (mapAttrsToList mkTimer   cfg.repos);
  };
}
