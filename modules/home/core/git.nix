{ pkgs, config, lib, flake, ... }:
let
  # Use flake config git settings
  flakeGit = flake.config.git or { };
  # Resolved theme palette (modules/home/theming). When this module is
  # evaluated standalone (no `my.theming`), resolve the catalog default from
  # lib/theming.nix instead of spelling a hex here — same palette, no literal.
  themingLib = import ../../../lib/theming.nix { inherit lib; };
  theme = config.my.theming.colors or (themingLib.mkColors { });
  inherit (theme) accent;
  muted = theme.foregroundMuted;
  # Get aliases from flake config, with fallback to defaults
  gitAliases = flakeGit.aliases or {
    co = "checkout";
    ci = "commit";
    cia = "commit --amend";
    s = "status";
    st = "status";
    b = "branch";
    pu = "push";
  };
in
{
  home.packages = with pkgs; [
    git-filter-repo
  ];

  programs.git = {
    enable = true;
    signing = {
      format = "openpgp";
      # Use flake config for signing settings
      signByDefault = flakeGit.signCommits or false;
      key = flakeGit.signingKey or null;
    };

    lfs.enable = true;

    ignores = [
      "*~"
      "*.swp"
    ];

    settings = {
      user = {
        name = flake.config.me.fullname;
        email = flake.config.me.email;
      };

      # Merge flake config aliases with any module-specific ones
      alias = gitAliases;

      # Use flake config for default branch
      init.defaultBranch = flakeGit.defaultBranch or "master";

      credential.helper = "store --file ~/.git-credentials";

      # Use flake config for pull rebase behavior
      pull.rebase = flakeGit.rebaseOnPull or false;

      branch.sort = "-committerdate";

      # Use flake config for rerere
      rerere.enabled = flakeGit.enableRerere or true;
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;

    options = {
      navigate = true;
      light = false;
      side-by-side = true;
      line-numbers = true;
      pager = "${pkgs.less}/bin/less --mouse --wheel-lines=3";
    };
  };

  programs.lazygit = {
    enable = true;
    # One owner for lazygit's theme. stylix's lazygit target sets the same
    # `gui.theme` keys from the same palette, and `yamlFormat.type` merges lists
    # by concatenation — with both active, `activeBorderColor` came out as the
    # accent/"bold" pair repeated twice. stylix wins where it is enabled (it maps
    # more keys, including lightTheme); this block is the non-stylix fallback.
    settings = {
      gui.theme = lib.mkIf (!(config.stylix.enable or false)) {
        lightTheme = false;
        activeBorderColor = [ accent "bold" ];
        inactiveBorderColor = [ muted ];
        selectedLineBgColor = [ "reverse" accent ];
      };
    };
  };
}
