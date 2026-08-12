{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf optionalString concatStringsSep optional;
  cfg = config.my.programs.minecraft;
  inherit (cfg) repo;
  git = "${pkgs.git}/bin/git";

  # Target directory for the sync: dataDir when set, otherwise the default
  # Prism Launcher data dir inside the user's home.
  repoPath =
    if cfg.dataDir != null then cfg.dataDir
    else "${config.home.homeDirectory}/.local/share/PrismLauncher";

  # ── Pull logic, driven by conflictStrategy ────────────────────────────────
  mkPullLogic =
    if repo.conflictStrategy == "ff-only" then ''
      ${git} -C "${repoPath}" merge --ff-only "$REF" 2>/dev/null \
        || echo "[minecraft-repo-sync] SKIP — fast-forward not possible (local commits or dirty tree)."
    ''
    else if repo.conflictStrategy == "reset-hard" then ''
      echo "[minecraft-repo-sync] resetting to $REF (destructive — local commits discarded)."
      ${git} -C "${repoPath}" reset --hard "$REF"
    ''
    else if repo.conflictStrategy == "stash-and-pull" then ''
      DIRTY=$(${git} -C "${repoPath}" status --porcelain 2>/dev/null)
      STASHED=0
      if [ -n "$DIRTY" ]; then
        echo "[minecraft-repo-sync] stashing local changes before pull."
        ${git} -C "${repoPath}" stash push --include-untracked -m "minecraft-repo-sync" \
          && STASHED=1 \
          || echo "[minecraft-repo-sync] SKIP — stash failed, leaving branch unchanged."
      fi

      if ! ${git} -C "${repoPath}" merge --ff-only "$REF" 2>/tmp/mc-sync-err; then
        echo "[minecraft-repo-sync] fast-forward failed after stash (diverged history?)." >&2
        cat /tmp/mc-sync-err >&2
      fi
      rm -f /tmp/mc-sync-err

      if [ "$STASHED" = "1" ]; then
        STASH_REF=$(${git} -C "${repoPath}" stash list --format="%gd %s" \
          | ${pkgs.gawk}/bin/awk '/minecraft-repo-sync/ {print $1; exit}')
        if [ -n "$STASH_REF" ]; then
          echo "[minecraft-repo-sync] restoring stashed changes."
          ${git} -C "${repoPath}" stash pop "$STASH_REF" 2>/tmp/mc-sync-pop-err \
            || {
              echo "[minecraft-repo-sync] WARNING — stash pop conflicted. Changes preserved in stash entry $STASH_REF." >&2
              cat /tmp/mc-sync-pop-err >&2
            }
          rm -f /tmp/mc-sync-pop-err
        fi
      fi
    ''
    else lib.throw "minecraft: unknown conflictStrategy '${repo.conflictStrategy}'";

  fetchArgs = concatStringsSep " " (
    optional repo.fetchPrune "--prune"
    ++ optional (repo.fetchDepth != null) "--depth ${toString repo.fetchDepth}"
  );

  syncScript = pkgs.writeShellScript "minecraft-repo-sync" ''
    set -euo pipefail

    GITHUB_TOKEN=""
    AUTHED_URL=""

    ${optionalString repo.agenix.enable ''
      TOKEN_FILE="${repo.agenix.secretPath}"
      if [ ! -f "$TOKEN_FILE" ]; then
        echo "[minecraft-repo-sync] WARNING: agenix secret not found at $TOKEN_FILE" >&2
      else
        GITHUB_TOKEN=$(cat "$TOKEN_FILE" | tr -d '[:space:]')
        AUTHED_URL=$(echo "${repo.url}" | ${pkgs.gnused}/bin/sed "s|https://|https://${repo.agenix.tokenUser}:$GITHUB_TOKEN@|")
      fi
    ''}

    CLONE_URL="''${AUTHED_URL:-${repo.url}}"

    # ── Clone if missing ──────────────────────────────────────────────────
    if [ ! -d "${repoPath}/.git" ]; then
      echo "[minecraft-repo-sync] Cloning ${repo.url} into ${repoPath} ..."
      mkdir -p "${repoPath}"
      CLONE_ARGS=""
      ${optionalString (repo.branch != null) ''CLONE_ARGS="$CLONE_ARGS --branch ${repo.branch}"''}
      ${optionalString (repo.fetchDepth != null) ''CLONE_ARGS="$CLONE_ARGS --depth ${toString repo.fetchDepth}"''}
      ${git} clone $CLONE_ARGS "$CLONE_URL" "${repoPath}"
      echo "[minecraft-repo-sync] clone complete."
    else
      # ── Fetch / pull ─────────────────────────────────────────────────────
      echo "[minecraft-repo-sync] Syncing ${repoPath} (strategy: ${repo.conflictStrategy}) ..."

      ${optionalString repo.agenix.enable ''
        if [ -n "$GITHUB_TOKEN" ]; then
          ORIG_URL=$(${git} -C "${repoPath}" remote get-url origin)
          ${git} -C "${repoPath}" remote set-url origin "$AUTHED_URL"
          trap '${git} -C "${repoPath}" remote set-url origin "$ORIG_URL"' EXIT
        fi
      ''}

      ${git} -C "${repoPath}" fetch origin ${fetchArgs}

      # Ensure the desired branch is checked out.
      CURRENT=$(${git} -C "${repoPath}" symbolic-ref --short HEAD 2>/dev/null || true)
      ${optionalString (repo.branch != null) ''
        if [ "$CURRENT" != "${repo.branch}" ]; then
          if ${git} -C "${repoPath}" checkout "${repo.branch}" 2>/dev/null; then
            echo "[minecraft-repo-sync] switched to '${repo.branch}'."
          else
            ${git} -C "${repoPath}" checkout -b "${repo.branch}" "origin/${repo.branch}"
          fi
        fi
      ''}

      # Resolve the ref to merge against: the desired branch, or the current
      # branch's remote-tracking ref when no branch is pinned.
      ${if repo.branch != null then ''
        REF="origin/${repo.branch}"
      '' else ''
        REF=$(${git} -C "${repoPath}" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
        if [ -z "$REF" ]; then
          echo "[minecraft-repo-sync] WARNING — no upstream set for current branch; skipping pull." >&2
          REF="origin/$CURRENT"
        fi
      ''}

      ${mkPullLogic}

      # ── Auto-push (push local commits upstream) ──────────────────────────
      ${optionalString repo.autoPush ''
        CURRENT=$(${git} -C "${repoPath}" symbolic-ref --short HEAD 2>/dev/null || true)
        if [ -n "$CURRENT" ]; then
          echo "[minecraft-repo-sync] pushing $CURRENT to origin ..."
          ${git} -C "${repoPath}" push origin "$CURRENT" 2>&1 \
            || echo "[minecraft-repo-sync] SKIP — push failed (no commits to push or permission denied)."
        fi
      ''}

      echo "[minecraft-repo-sync] sync complete."
    fi
  '';
in
{
  config = mkIf (cfg.enable && cfg.repo != null) {
    systemd.user.services.minecraft-repo-sync = {
      Unit = {
        Description = "Prism Launcher data dir git repo sync";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${syncScript}";
        Environment = [
          "HOME=${config.home.homeDirectory}"
          "GIT_TERMINAL_PROMPT=0"
          "PATH=${lib.makeBinPath [ pkgs.git pkgs.gnused pkgs.gawk pkgs.coreutils ]}"
        ];
      };
    };

    systemd.user.timers.minecraft-repo-sync = {
      Unit = {
        Description = "Prism Launcher data dir git repo sync timer";
      };
      Timer = {
        OnBootSec = repo.onBootDelaySec;
        OnUnitActiveSec = repo.interval;
        OnActiveSec = repo.interval;
        Persistent = repo.timerPersistent;
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };
}
