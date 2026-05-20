{ config, pkgs, lib, flake, ... }:
let
  cfg = config.my.system.userDefaults;
  # Get preferences and defaults from flake config
  prefs = flake.config.preferences or { };
  defaults = flake.config.defaults or { };
in
{
  options.my.system.userDefaults = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable user default applications and environment variables from config.nix";
    };
  };

  config = lib.mkIf cfg.enable {
    # Set XDG default applications
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        # Web browser
        "text/html" = "${defaults.browser or "firefox"}.desktop";
        "x-scheme-handler/http" = "${defaults.browser or "firefox"}.desktop";
        "x-scheme-handler/https" = "${defaults.browser or "firefox"}.desktop";
        "x-scheme-handler/about" = "${defaults.browser or "firefox"}.desktop";
        "x-scheme-handler/unknown" = "${defaults.browser or "firefox"}.desktop";

        # Email
        "x-scheme-handler/mailto" = "${defaults.emailClient or "thunderbird"}.desktop";
        "message/rfc822" = "${defaults.emailClient or "thunderbird"}.desktop";

        # File manager
        "inode/directory" = "${defaults.fileManager or "nautilus"}.desktop";
      };
    };

    # Set environment variables based on preferences
    home.sessionVariables = {
      # Default editor
      EDITOR = prefs.editor or "nvim";
      VISUAL = prefs.editor or "nvim";

      # Terminal
      TERMINAL = defaults.terminal or "ghostty";

      # Browser
      BROWSER = defaults.browser or "firefox";

      # Locale if specified
      LANG = flake.config.location.defaultLocale or "en_GB.UTF-8";
    };

    # Configure shell based on preferences
    programs.bash = lib.mkIf ((prefs.shell or "zsh") == "bash") {
      enable = true;
    };

    programs.zsh = lib.mkIf ((prefs.shell or "zsh") == "zsh") {
      enable = true;
    };

    programs.fish = lib.mkIf ((prefs.shell or "zsh") == "fish") {
      enable = true;
    };
  };
}
