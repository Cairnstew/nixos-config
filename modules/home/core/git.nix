{ pkgs, config, lib, flake, ... }:
let
  # Use flake config git settings
  flakeGit = flake.config.git or { };
  scheme = flake.config.me.colorScheme or { };
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
    settings = {
      gui.theme = {
        lightTheme = false;
        activeBorderColor = [ (scheme.accent or "white") "bold" ];
        inactiveBorderColor = [ (scheme.base04 or "white") ];
        selectedLineBgColor = [ "reverse" (scheme.accent or "white") ];
      };
    };
  };
}
