{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf optional optionalString concatStringsSep concatMapStrings mapAttrsToList hasPrefix;
  cfg = config.my.services.gitRepoSync;
  git = "${pkgs.git}/bin/git";

  # ── Per-branch pull logic, driven by conflictStrategy ──────────────────────
  mkPullLogic = name: repo: branch:
    let
      repoPath = repo.path;
      ref = "${repo.remote}/${branch}";
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
          | ${pkgs.gawk}/bin/awk '/${stashMsg}/ {print $1; exit}')
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

    else lib.throw "git-repo-sync: unknown conflictStrategy '${repo.conflictStrategy}'";

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
    if repo.branches == [ ] then ''
      ${git} -C "${repo.path}" fetch ${repo.remote} ${fetchArgs}
      ${optionalString repo.autoPull guardedPullCurrent}
    ''
    else
      concatMapStrings
        (branch: ''
          ${git} -C "${repo.path}" fetch ${repo.remote} ${fetchArgs} "${branch}:${branch}" 2>/dev/null \
            || ${git} -C "${repo.path}" fetch ${repo.remote} ${fetchArgs}
          ${optionalString repo.autoPull (guardedPull branch)}
        '')
        repo.branches;

  # ── Shell script for one repo ──────────────────────────────────────────────
  mkSyncScript = name: repo:
    let
      tokenEnv = optionalString repo.agenix.enable ''
        GITHUB_TOKEN_FILE="${repo.agenix.secretPath}"
        if [ ! -f "$GITHUB_TOKEN_FILE" ]; then
          echo "[git-repo-sync] WARNING: agenix secret not found at $GITHUB_TOKEN_FILE" >&2
        else
          GITHUB_TOKEN=$(cat "$GITHUB_TOKEN_FILE" | tr -d '[:space:]')
          AUTHED_URL=$(echo "${repo.url}" | ${pkgs.gnused}/bin/sed "s|https://|https://${repo.agenix.tokenUser}:$GITHUB_TOKEN@|")
        fi
      '';

      cloneUrl =
        if repo.agenix.enable
        then "\${AUTHED_URL:-${repo.url}}"
        else repo.url;

    in
    pkgs.writeShellScript "git-repo-sync-${name}" ''
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
        OnActiveSec = repo.interval;
        Persistent = repo.timerPersistent;
      };
      wantedBy = [ "timers.target" ];
    };
  };

in
{
  config = mkIf cfg.enable {
    systemd.user.services = lib.mkMerge (mapAttrsToList mkService cfg.repos);
    systemd.user.timers = lib.mkMerge (mapAttrsToList mkTimer cfg.repos);
  };
}
