{ lib, pkgs, ... }:

let
  inherit (lib) types mkOption;

  repoOpts = _: {
    options = {
      url = mkOption {
        type = types.str;
        description = "Remote URL of the Prism Launcher data repo (https or ssh).";
        example = "https://github.com/Cairnstew/prismlauncher-data.git";
      };

      branch = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Branch to check out after every sync. null = leave the current branch.";
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

      conflictStrategy = mkOption {
        type = types.enum [ "ff-only" "stash-and-pull" "reset-hard" ];
        default = "stash-and-pull";
        description = ''
          How to integrate remote changes.

            ff-only        Safe default. Skips the pull and logs a warning when a
                           fast-forward is not possible. Never rewrites history or
                           discards work.

            stash-and-pull Stashes local modifications (staged + unstaged), fast-forwards,
                           then pops the stash. Best when you make local tweaks
                           (instance configs, saves) that should not be lost.

            reset-hard     Discards all local commits and resets to the remote branch
                           exactly. Treats the data dir as a read-only mirror.
                           DESTRUCTIVE: any unpushed work is permanently lost.
        '';
        example = "ff-only";
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

      autoPush = mkOption {
        type = types.bool;
        default = false;
        description = ''
          After syncing, push local commits on the current branch to the remote.
          Requires write access to the remote (SSH key or agenix token). Useful for
          pushing new saves / instance progress back to the GitHub repo.
        '';
      };

      agenix = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable agenix-based GitHub token injection for private repos.
            Token is read from disk at runtime — never stored in the Nix store.
          '';
        };

        secretPath = mkOption {
          type = types.str;
          default = "/run/agenix/github-token-prismlauncher";
          description = "Path to the agenix-decrypted file containing the raw GitHub token.";
          example = "/run/agenix/github-token-prismlauncher";
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
in
{
  options.my.programs.minecraft = {
    enable = lib.mkEnableOption "Minecraft client launcher";

    launcher = lib.mkOption {
      type = types.enum [ "prismlauncher" "modrinth-app" ];
      default = "prismlauncher";
      description = ''
        Which launcher to install.
        - prismlauncher: MultiMC fork with built-in Modrinth and CurseForge
          browsing per instance and auto Java selection (GPL, free).
        - modrinth-app: official Modrinth launcher (unfree bundled assets).
      '';
    };

    package = lib.mkOption {
      type = types.nullOr types.package;
      default = null;
      description = ''
        Override the launcher package entirely, e.g.
        prismlauncher.override { additionalLibs = [ ... ]; }. When set,
        `launcher` and `jdks` are ignored.
      '';
    };

    jdks = lib.mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = [ pkgs.jdk21 ];
      description = ''
        Extra JDKs exposed to the launcher via PRISMLAUNCHER_JAVA_PATHS / PATH.
        Minecraft needs specific Java: ≤1.16.5 → Java 8-16, 1.18+ → 17,
        1.20.5+ → 21.
      '';
    };

    extraPackages = lib.mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = [ pkgs.ferium pkgs.mrpack-install pkgs.mcaselector ];
      description = "Extra Minecraft-related packages (mod managers, tools).";
    };

    dataDir = lib.mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/mnt/media/Modding/PrismLauncher";
      description = ''
        Prism Launcher data directory (application root: instances, libraries,
        assets, …). Passed via <literal>--dir</literal> on every launch through
        a launcher wrapper. Defaults to <literal>~/.local/share/PrismLauncher</literal>.
        Set to a path on a large drive (e.g.
        <literal>/mnt/media/Modding/PrismLauncher</literal>) to keep the system
        SSD free. Only applies to the <literal>prismlauncher</literal> launcher.
      '';
    };

    repo = lib.mkOption {
      type = types.nullOr (types.submodule repoOpts);
      default = null;
      description = ''
        A git remote (e.g. a GitHub repo) that mirrors the Prism Launcher data
        directory. When set, a systemd user timer keeps the data dir in sync
        with the remote — cloning it on first run if missing, then pulling on
        an interval using <literal>conflictStrategy</literal>. Reuses the same
        clone/fetch/pull machinery as <option>my.services.gitRepoSync</option>
        but scoped to the launcher data dir, so no separate gitRepoSync repo
        entry is needed. Syncs into <option>dataDir</option> when set,
        otherwise the default <literal>~/.local/share/PrismLauncher</literal>.
      '';
    };

    gamescope = {
      enable = lib.mkEnableOption "wrap the launcher in gamescope (FPS cap / NVIDIA Wayland stability)";

      package = lib.mkOption {
        type = types.package;
        default = pkgs.gamescope;
        defaultText = lib.literalExpression "pkgs.gamescope";
        description = "The gamescope package to use for wrapping.";
      };
    };
  };
}
