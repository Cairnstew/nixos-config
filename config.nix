# Configuration for this repo
# See ./modules/flake-parts/config.nix for module options.
{
  # ============================================================================
  # User Identity (me.*)
  # ============================================================================
  # These values define the primary user for all systems in this flake.
  # Consumed by: modules/nixos/common.nix (user creation), home-manager configs,
  #              git configuration, SSH key deployment.
  # If unset: Host configurations will fail to evaluate (required fields).
  # ============================================================================
  me = {
    # Primary username for all systems.
    # Consumed by: users.users.<name>, home-manager users, file paths.
    username = "seanc";

    # Full display name (used for git config, user info).
    # Consumed by: programs.git.userName, various UI displays.
    fullname = "Sean Cairns";
    
    # Email address (used for git, accounts, notifications).
    # Consumed by: programs.git.userEmail, service account configs.
    email = "sean.cairnsst@gmail.com";

    # SSH public key for this user (ed25519).
    # Consumed by: users.users.<name>.openssh.authorizedKeys,
    #              agenix secret encryption (can decrypt all secrets).
    # If changed: Must re-encrypt all agenix secrets with new key.
    sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPWrhAp1ZU9p7UvJ1x9ApM1pY9OK2S8crEKHeEAxX0z6 sean.cairnsst@gmail.com";

    # GitHub username for gh CLI and git remote operations.
    # Consumed by: programs.gh, git remote defaults.
    github_username = "Cairnstew";
  };

  # ============================================================================
  # User Preferences (preferences.*)
  # ============================================================================
  # Personal preferences used across desktop environments and applications.
  # These are defaults that can be overridden per-host if needed.
  # ============================================================================
  preferences = {
    # UI theme preference (dark/light)
    # Consumed by: GTK settings, terminal configs, application themes
    darkMode = true;

    # Default terminal font (monospace)
    # Consumed by: ghostty, VSCode, terminal configurations
    terminalFont = "JetBrainsMono Nerd Font";

    # Default terminal font size
    terminalFontSize = 11;

    # Preferred shell
    # Consumed by: user shell configuration, terminal settings
    shell = "zsh"; # Options: "bash", "zsh", "fish"

    # Default editor for CLI operations (EDITOR environment variable)
    # Consumed by: shell configs, git, various CLI tools
    editor = "nano"; # Options: "nvim", "vim", "nano", "emacs"

    # Keyboard layout
    # Consumed by: X11/Wayland keyboard settings, console keymap
    keyboardLayout = "gb";

    # Enable emacs-style keybindings in terminal/shell
    # Consumed by: readline configuration, shell settings
    emacsKeybindings = false;
  };

  # ============================================================================
  # Default Applications (defaults.*)
  # ============================================================================
  # Default applications for common operations.
  # These are used by desktop environments and xdg-mime.
  # ============================================================================
  defaults = {
    # Default web browser
    # Consumed by: xdg settings, desktop shortcuts
    browser = "firefox";

    # Default email client
    # Consumed by: desktop entries, mailto: handlers
    emailClient = "thunderbird";

    # Default terminal emulator
    # Consumed by: desktop shortcuts, terminal launcher
    terminal = "ghostty";

    # Default file manager
    # Consumed by: desktop entries, file:// handlers
    fileManager = "nautilus";
  };

  # ============================================================================
  # Location and Locale (location.*)
  # ============================================================================
  # Geographic location and timezone settings.
  # Used by: timezone configuration, location-based services,
  #          redshift/night light, weather applications.
  # ============================================================================
  location = {
    # IANA timezone identifier
    # Consumed by: system.time.timeZone, cron jobs, scheduled tasks
    timeZone = "Europe/London";

    # Geographic coordinates for location-based services
    # Consumed by: redshift, night light, weather apps
    latitude = 55.8617;
    longitude = -4.2583;

    # Locale settings (affects date/time formatting, collation)
    # Consumed by: i18n settings, application locales
    defaultLocale = "en_GB.UTF-8";
  };

  # ============================================================================
  # Git Configuration (git.*)
  # ============================================================================
  # Git-specific preferences and defaults.
  # These are applied to all systems via home-manager.
  # ============================================================================
  git = {
    # Default branch name for new repositories
    # Consumed by: programs.git.settings.init.defaultBranch
    defaultBranch = "master";

    # Sign commits by default
    # Consumed by: programs.git.signing.signByDefault
    signCommits = false;

    # GPG/SSH signing key (if signing is enabled)
    # Consumed by: programs.git.signing.key
    signingKey = null;

    # Default merge strategy
    # Consumed by: programs.git.settings.pull.rebase
    # true = use rebase, false = use merge commits
    rebaseOnPull = false;

    # Enable git rerere (reuse recorded resolution)
    # Consumed by: programs.git.settings.rerere.enabled
    enableRerere = true;

    # Additional git aliases
    # Consumed by: programs.git.settings.alias
    aliases = {
      co = "checkout";
      ci = "commit";
      cia = "commit --amend";
      s = "status";
      st = "status";
      b = "branch";
      pu = "push";
      pf = "push --force-with-lease";
      lg = "log --oneline --graph --decorate";
    };
  };

  # ============================================================================
  # SSH Configuration (ssh.*)
  # ============================================================================
  # SSH client preferences and defaults.
  # ============================================================================
  ssh = {
    # SSH key type for new key generation
    # Consumed by: my.services.ssh.keyType
    keyType = "ed25519";

    # Default SSH key path (relative to ~)
    # Consumed by: my.services.ssh.keyPath
    keyPath = "~/.ssh/id_ed25519";

    # Automatically add keys to SSH agent
    # Consumed by: my.services.ssh.addKeysToAgent
    addKeysToAgent = true;

    # SSH agent forwarding (be careful with this on shared systems)
    # Consumed by: my.services.tailscale.ssh.extraHostConfig
    forwardAgent = true;

    # Default keepalive interval in seconds (0 to disable)
    # Consumed by: SSH match block settings
    serverAliveInterval = 60;
  };

  # ============================================================================
  # Tailscale Network (tailnet.*)
  # ============================================================================
  # Known hosts in the Tailscale tailnet for SSH, service URLs, and MagicDNS.
  # Consumed by: SSH client config, service URLs, firewall rules, deployment targets.
  # If unset: SSH host aliases and service discovery will not work.
  # ============================================================================
  tailnet = {
    # Server host (headless, primary infrastructure).
    # Consumed by: deployment scripts, SSH config, service proxy settings.
    server = { ip = "100.119.248.77"; hostname = "server"; magicDnsName = "server.tail685690.ts.net"; };

    # Laptop (mobile workstation).
    # Consumed by: sync targets, SSH host alias.
    laptop = { ip = "100.108.181.64"; hostname = "laptop"; magicDnsName = "laptop.tail685690.ts.net"; };

    # WSL instance (Windows subsystem for Linux).
    # Consumed by: cross-platform sync, development environment.
    wsl = { ip = "100.70.224.82"; hostname = "wsl"; magicDnsName = "wsl.tail685690.ts.net"; };

    # Desktop workstation (Intel, primary development).
    # Consumed by: build distribution, remote builder configuration.
    desktop-dlstflt = { ip = "100.111.231.84"; hostname = "desktop-dlstflt"; magicDnsName = "desktop-dlstflt.tail685690.ts.net"; };
  };

  # ============================================================================
  # Ollama Language Models (ollamaModels.*)
  # ============================================================================
  # Configuration for locally-hosted AI models via Ollama.
  # Consumed by: modules/nixos/ollama (model pulling), aider (coding assistant),
  #              Cline/Opencode AI assistant integrations.
  # If unset: Local AI features will use hardcoded defaults or fail to start.
  # ============================================================================
  ollamaModels = {
    "deepseek-coder-v2:16b" = {
      # Model identifier (must match Ollama hub name).
      name = "deepseek-coder-v2:16b";
      # Whether model supports tool/function calling.
      tools = true;
      # Context window size (affects memory usage).
      numCtx = 32768;
      # Sampling temperature (0-2, higher = more creative).
      temperature = 0.7;
      # Nucleus sampling threshold.
      topP = 0.90;
      # Top-k sampling limit.
      topK = 40;
      # Repetition penalty (1.0 = none, higher = stronger).
      repeatPenalty = 1.1;

      # Default for aider coding assistant.
      aider_default = false;
    };
    "qwen2.5-coder:7b" = {
      name = "qwen2.5-coder:7b";
      tools = true;
      numCtx = 32768;
      temperature = 0.7;
      topP = 0.90;
      topK = 40;
      repeatPenalty = 1.1;

      aider_default = false;
    };
    "qwen2.5-coder:14b-instruct" = {
      name = "qwen2.5-coder:14b-instruct";
      tools = true;
      numCtx = 32768;
      temperature = 0.7;
      topP = 0.90;
      topK = 40;
      repeatPenalty = 1.1;

      aider_default = false;
      cline_default = false;
    };
    "hermes3:8b" = {
      name = "hermes3:8b";
      tools = true;
      numCtx = 32768;
      temperature = 0.1;
      topP = 0.90;
      topK = 40;
      repeatPenalty = 1.1;

      aider_default = false;
      cline_default = false;
    };
    "gemma4:e4b" = {
      name = "gemma4:e4b";
      tools = true;
      numCtx = 32768;
      # Low temperature for consistent agentic outputs.
      temperature = 0.10;
      # Higher topP for creative diversity.
      topP = 0.95;
      topK = 64;

      # Default model for Cline AI assistant.
      cline_default = true;
      # Default model for aider coding assistant.
      aider_default = true;
      # Default model for Opencode AI assistant.
      opencode_default = true;
    };
  };
}
