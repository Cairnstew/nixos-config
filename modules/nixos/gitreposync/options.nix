{ lib, ... }:

let
  inherit (lib) mkOption mkEnableOption types literalExpression;

  repoOpts = { name, ... }: {
    options = {
      homeDir = mkOption {
        type = types.str;
        default = "%h";
        description = "Home directory for the HOME environment variable. Defaults to %h (systemd user home specifier).";
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
          example = "/run/agenix/github/repos/my-repo";
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
  options.my.services.gitRepoSync = {
    enable = mkEnableOption "git repository sync service" // { default = false; };

    user = mkOption {
      type = types.str;
      description = "User whose systemd session should run the timers.";
      example = "alice";
    };

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
        }
      '';
    };
  };
}
