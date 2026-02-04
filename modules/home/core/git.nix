{ pkgs, flake, ... }:
{
  home.packages = with pkgs; [
    git-filter-repo
  ];

  programs.git = {
    enable = true;
  
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
  
      alias = {
        co  = "checkout";
        ci  = "commit";
        cia = "commit --amend";
        s   = "status";
        st  = "status";
        b   = "branch";
        pu  = "push";
      };
  
      init.defaultBranch = "master";
  
      credential.helper = "store --file ~/.git-credentials";
  
      pull.rebase = false;
  
      branch.sort = "-committerdate";
  
      rerere.enabled = true;
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
      # This looks better with the kitty theme.
      gui.theme = {
        lightTheme = false;
        activeBorderColor = [ "white" "bold" ];
        inactiveBorderColor = [ "white" ];
        selectedLineBgColor = [ "reverse" "white" ];
      };
    };
  };
}
