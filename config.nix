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

    # Catppuccin Mocha color palette
    # All values with # prefix; consumers strip when needed.
    colorScheme = {
      slug = "catppuccin-mocha";

      # Base16 00-0F palette
      base00 = "#1e1e2e";
      base01 = "#181825";
      base02 = "#313244";
      base03 = "#45475a";
      base04 = "#585b70";
      base05 = "#cdd6f4";
      base06 = "#f5f5f5";
      base07 = "#ffffff";
      base08 = "#f38ba8";
      base09 = "#fab387";
      base0A = "#f9e2af";
      base0B = "#a6e3a1";
      base0C = "#94e2d5";
      base0D = "#89b4fa";
      base0E = "#f5c2e7";
      base0F = "#cba6f7";

      # Semantic aliases
      background = "#1e1e2e";
      foreground = "#cdd6f4";
      cursor = "#f5e0dc";
      accent = "#89b4fa";
    };
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
    keyboardLayout = "us";

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
    server = { ip = "100.78.102.28"; hostname = "server"; magicDnsName = "server.tail685690.ts.net"; };

    # Laptop (mobile workstation).
    # Consumed by: sync targets, SSH host alias.
    laptop = { ip = "100.108.181.64"; hostname = "laptop"; magicDnsName = "laptop.tail685690.ts.net"; };

    # WSL instance (Windows subsystem for Linux).
    # Consumed by: cross-platform sync, development environment.
    wsl = { ip = "100.70.224.82"; hostname = "wsl"; magicDnsName = "wsl.tail685690.ts.net"; };

    # Desktop workstation (Intel, primary development).
    # Consumed by: build distribution, remote builder configuration.
    desktop-dlstflt = { ip = "100.111.231.84"; hostname = "desktop-dlstflt"; magicDnsName = "desktop-dlstflt.tail685690.ts.net"; };

    # (New) Desktop PC — dual-boot NixOS + Windows 11.
    # TODO: Fill in IP/hostname after first install and Tailscale login.
    # desktop = { ip = "..."; hostname = "desktop"; magicDnsName = "..."; };
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
    "hf.co/Lewdiculous/InfinityRP-v1-7B-GGUF-IQ-Imatrix:Q4_K_M-imat" = {
      name = "hf.co/Lewdiculous/InfinityRP-v1-7B-GGUF-IQ-Imatrix:Q4_K_M-imat";
      tools = false;
      numCtx = 8192;
      temperature = 0.9;
      topP = 0.95;
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
    "hf.co/Lewdiculous/DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small-GGUF-IQ-Imatrix:Q4_K_M-imat" = {
      name = "hf.co/Lewdiculous/DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small-GGUF-IQ-Imatrix:Q4_K_M-imat";
      tools = false;
      numCtx = 32768;
      temperature = 1.0;
      topP = 1.0;
      topK = 40;
      repeatPenalty = 1.0;

      aider_default = false;
      cline_default = false;
    };
  };

  # ============================================================================
  # Mail Organization (mail.*)
  # ============================================================================
  # Canonical tag/folder taxonomy for email organization in Gmail/Thunderbird.
  # Each entry maps to a Gmail label (folder path). Used for manual sorting,
  # auto-filtering rules, and as a searchable reference.
  #
  # Consumed by: manual inbox sorting, Gmail filter definitions, Thunderbird config.
  # See: modules/flake-parts/config.nix for option declarations.
  # ============================================================================
  mail = {
    tags = {
      # ── Action Required ──────────────────────────────────────────────
      "Action/@todo" = {
        path = "Action/@todo";
        description = "Emails requiring a response or action from me";
        matchers = [ ];
        aliases = [ "todo" "action" "inbox" ];
      };
      "Action/@waiting" = {
        path = "Action/@waiting";
        description = "Emails I'm waiting on someone else to respond to";
        matchers = [ "waiting" "follow up" ];
        aliases = [ "waiting" "deferred" ];
      };
      "Action/@followup" = {
        path = "Action/@followup";
        description = "Emails to check back on later";
        matchers = [ "follow" "remind" ];
        aliases = [ "fup" "check" ];
      };

      # ── Security ─────────────────────────────────────────────────────
      "Security/1Password" = {
        path = "Security/1Password";
        description = "1Password sign-in alerts and security notifications";
        matchers = [ "1password" "hello@1password.com" ];
        aliases = [ "passwords" "auth" ];
      };
      "Security/Google" = {
        path = "Security/Google";
        description = "Google account security alerts and sign-in notifications";
        matchers = [ "google" "accounts.google.com" "security alert" ];
        aliases = [ "gmail" "google-auth" ];
      };
      "Security/Spotify" = {
        path = "Security/Spotify";
        description = "Spotify login codes and account alerts";
        matchers = [ "spotify" "alerts.spotify.com" "login code" ];
        aliases = [ "spotify-auth" ];
      };
      "Security/GitHub" = {
        path = "Security/GitHub";
        description = "GitHub security alerts, token creation, and access notifications";
        matchers = [ "github.com" "personal access token" "security" ];
        aliases = [ "github-security" ];
      };

      # ── Finance ──────────────────────────────────────────────────────
      "Finance/Orders" = {
        path = "Finance/Orders";
        description = "Purchase confirmations, receipts, and order status";
        matchers = [ "amazon" "order" "receipt" "confirmation" "purchase" ];
        aliases = [ "receipts" "purchases" "shopping" ];
      };
      "Finance/Banking" = {
        path = "Finance/Banking";
        description = "Bank statements, transaction alerts, and account notices";
        matchers = [ "monzo" "peakbank" "truwest" "bank" "statement" ];
        aliases = [ "bank" "accounts" ];
      };
      "Finance/PayPal" = {
        path = "Finance/PayPal";
        description = "PayPal transactions, offers, and account notifications";
        matchers = [ "paypal" "venmo" ];
        aliases = [ "payments" ];
      };

      # ── Education ────────────────────────────────────────────────────
      "Education/GCU" = {
        path = "Education/GCU";
        description = "GCU coursework, admin, and university communications";
        matchers = [ "gcu" "grand canyon" ];
        aliases = [ "gcu" "university" ];
      };
      "Education/UTD" = {
        path = "Education/UTD";
        description = "UT Dallas coursework, admin, and university communications";
        matchers = [ "utd" "ut dallas" "dallas" ];
        aliases = [ "utd" "university" ];
      };
      "Education/Gradcracker" = {
        path = "Education/Gradcracker";
        description = "Gradcracker job listings and career opportunities";
        matchers = [ "gradcracker" "jessica@gradcracker" ];
        aliases = [ "jobs" "careers" "graduate" ];
      };

      # ── Work ─────────────────────────────────────────────────────────
      "Work/GitHub" = {
        path = "Work/GitHub";
        description = "GitHub notifications: CI, PRs, issues, actions";
        matchers = [ "notifications@github.com" "github.com" "ci" "check-suites" ];
        aliases = [ "dev" "code" ];
      };
      "Work/Applications" = {
        path = "Work/Applications";
        description = "Job applications, interviews, and recruitment";
        matchers = [ "application" "interview" "job" "hiring" "recruit" ];
        aliases = [ "jobs" "career" "hiring" ];
      };
      "Work/Infra" = {
        path = "Work/Infra";
        description = "Infrastructure, Tableau, Cloudflare, and platform tools";
        matchers = [ "tableau" "cloudflare" "infra" "platform" "salesforce" ];
        aliases = [ "devops" "platform" ];
      };
      "Work/General" = {
        path = "Work/General";
        description = "General work correspondence and misc professional";
        matchers = [ ];
        aliases = [ "professional" ];
      };

      # ── Personal ─────────────────────────────────────────────────────
      "Personal/Family" = {
        path = "Personal/Family";
        description = "Family communications and updates";
        matchers = [ "family" "mum" "dad" "brother" "sister" ];
        aliases = [ "family" ];
      };
      "Personal/Health" = {
        path = "Personal/Health";
        description = "Medical appointments, dental, fitness, and wellness";
        matchers = [ "dental" "dentist" "doctor" "appointment" "fitness" "gym" "24 hour" ];
        aliases = [ "medical" "fitness" "doctor" ];
      };
      "Personal/Travel" = {
        path = "Personal/Travel";
        description = "Travel bookings, itineraries, trip planning";
        matchers = [ "travel" "flight" "hotel" "booking" "itinerary" "scotland" ];
        aliases = [ "trips" "vacation" "holiday" ];
      };
      "Personal/Events" = {
        path = "Personal/Events";
        description = "Events, invitations, social gatherings";
        matchers = [ "event" "invite" "rsvp" "party" "gathering" ];
        aliases = [ "social" "calendar" ];
      };
      "Personal/Social" = {
        path = "Personal/Social";
        description = "Social media notifications (Instagram, etc.)";
        matchers = [ "instagram" "facebook" "social" "notification" ];
        aliases = [ "instagram" "social-media" ];
      };
      "Personal/Community" = {
        path = "Personal/Community";
        description = "Community groups, art league, local organizations";
        matchers = [ "art league" "dsal" "artindripping" "habitat" "volunteer" ];
        aliases = [ "art" "community" "volunteer" ];
      };

      # ── Promo ────────────────────────────────────────────────────────
      "Promo/Retail" = {
        path = "Promo/Retail";
        description = "Retail promotions and marketing (Lowe's, Target, etc.)";
        matchers = [ "lowes" "target" "elegoo" "kiiroo" "ancestry" "sale" "deal" ];
        aliases = [ "marketing" "deals" "sales" "ads" ];
      };
      "Promo/Food" = {
        path = "Promo/Food";
        description = "Food and drink promotions and offers";
        matchers = [ "velvet taco" "taco" "restaurant" "food" "marg" ];
        aliases = [ "food" "dining" "restaurants" ];
      };
      "Promo/Services" = {
        path = "Promo/Services";
        description = "Service promotions (Grammarly, etc.)";
        matchers = [ "grammarly" "service" "premium" "offer" "upgrade" ];
        aliases = [ "subscriptions" "services" ];
      };

      # ── Delivery ─────────────────────────────────────────────────────
      "Delivery/Parcels" = {
        path = "Delivery/Parcels";
        description = "Parcel tracking, shipping updates, delivery notifications";
        matchers = [ "royal mail" "parcel" "shipping" "dispatched" "tracking" "delivered" ];
        aliases = [ "packages" "shipping" "tracking" ];
      };

      # ── Notifications ────────────────────────────────────────────────
      "Notifications/Updates" = {
        path = "Notifications/Updates";
        description = "Service updates, privacy policy changes, account notices";
        matchers = [ "privacy policy" "update" "terms" "notice" ];
        aliases = [ "updates" "notices" ];
      };

      # ── Volunteer ────────────────────────────────────────────────────
      "Volunteer" = {
        path = "Volunteer";
        description = "Volunteer opportunities and coordination";
        matchers = [ "volunteer" "signupgenius" "hh thursday" ];
        aliases = [ "charity" "community-service" ];
      };

      # ── Gaming ───────────────────────────────────────────────────────
      "Gaming" = {
        path = "Gaming";
        description = "Gaming-related emails, promotions, and registrations";
        matchers = [ "g2a" "call of duty" "steam" "gaming" "activision" ];
        aliases = [ "games" "steam" ];
      };
    };
  };
}
