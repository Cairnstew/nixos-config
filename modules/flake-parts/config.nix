# =============================================================================
# config.nix — Flake-Level Identity and Configuration Schema
# =============================================================================
# Purpose: Defines typed options for user identity, preferences, and system
#          configurations. Imports and exposes values from `../../config.nix`.
#
# Inputs: ../../config.nix — actual values (separated for easy editing)
#
# Outputs:
#   - options.me — user identity (username, email, SSH key, etc.)
#   - options.preferences — UI/UX preferences (theme, fonts, shell, editor)
#   - options.defaults — default applications (browser, email, terminal)
#   - options.location — timezone and geographic location
#   - options.git — git configuration defaults
#   - options.ssh — SSH client preferences
#   - options.tailnet — Tailscale network host definitions
#   - options.ollamaModels — AI model configurations for local inference
#
# Consumed by: Modules throughout the flake via `config.*`
# =============================================================================

# Top-level configuration for everything in this repo.
#
# Values are set in 'config.nix' in repo root.
{ lib, ... }:
let
  userSubmodule = lib.types.submodule {
    options = {
      username = lib.mkOption {
        type = lib.types.str;
        description = "Primary username for all systems.";
      };
      fullname = lib.mkOption {
        type = lib.types.str;
        description = "Full display name for git and UI.";
      };
      email = lib.mkOption {
        type = lib.types.str;
        description = "Email address for git, accounts, and notifications.";
      };
      sshKey = lib.mkOption {
        type = lib.types.str;
        description = ''
          SSH public key for this user.
          Used for authorized_keys and agenix encryption.
        '';
      };
      github_username = lib.mkOption {
        type = lib.types.str;
        description = "GitHub username for gh CLI and git remotes.";
      };
    };
  };

  preferencesSubmodule = lib.types.submodule {
    options = {
      darkMode = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable dark mode for applications and desktop environment.";
      };
      terminalFont = lib.mkOption {
        type = lib.types.str;
        default = "JetBrainsMono Nerd Font";
        description = "Default monospace font for terminals and editors.";
      };
      terminalFontSize = lib.mkOption {
        type = lib.types.int;
        default = 11;
        description = "Default terminal font size in points.";
      };
      shell = lib.mkOption {
        type = lib.types.enum [ "bash" "zsh" "fish" ];
        default = "zsh";
        description = "Preferred login shell.";
      };
      editor = lib.mkOption {
        type = lib.types.str;
        default = "nvim";
        description = "Default CLI editor (sets EDITOR environment variable).";
      };
      keyboardLayout = lib.mkOption {
        type = lib.types.str;
        default = "us";
        description = "Default keyboard layout (XKB layout code).";
      };
      emacsKeybindings = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable emacs-style keybindings in readline and shell.";
      };
    };
  };

  defaultsSubmodule = lib.types.submodule {
    options = {
      browser = lib.mkOption {
        type = lib.types.str;
        default = "firefox";
        description = "Default web browser application.";
      };
      emailClient = lib.mkOption {
        type = lib.types.str;
        default = "thunderbird";
        description = "Default email client application.";
      };
      terminal = lib.mkOption {
        type = lib.types.str;
        default = "ghostty";
        description = "Default terminal emulator application.";
      };
      fileManager = lib.mkOption {
        type = lib.types.str;
        default = "nautilus";
        description = "Default file manager application.";
      };
    };
  };

  locationSubmodule = lib.types.submodule {
    options = {
      timeZone = lib.mkOption {
        type = lib.types.str;
        default = "Europe/London";
        description = "IANA timezone identifier (e.g., 'Europe/London', 'America/New_York').";
      };
      latitude = lib.mkOption {
        type = lib.types.float;
        default = 51.5074;
        description = "Latitude for location-based services (redshift, night light, weather).";
      };
      longitude = lib.mkOption {
        type = lib.types.float;
        default = -0.1278;
        description = "Longitude for location-based services.";
      };
      defaultLocale = lib.mkOption {
        type = lib.types.str;
        default = "en_GB.UTF-8";
        description = "Default system locale for formatting dates, numbers, etc.";
      };
    };
  };

  gitSubmodule = lib.types.submodule {
    options = {
      defaultBranch = lib.mkOption {
        type = lib.types.str;
        default = "master";
        description = "Default branch name for new git repositories.";
      };
      signCommits = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to sign commits by default.";
      };
      signingKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "GPG or SSH key ID for signing commits (null to disable).";
      };
      rebaseOnPull = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use rebase instead of merge when pulling (true = cleaner history, false = merge commits).";
      };
      enableRerere = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable git rerere (reuse recorded resolution for repeated merges).";
      };
      aliases = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Additional git aliases (attribute set of alias = command).";
        example = lib.literalExpression ''
          {
            co = "checkout";
            ci = "commit";
            lg = "log --oneline --graph";
          }
        '';
      };
    };
  };

  sshSubmodule = lib.types.submodule {
    options = {
      keyType = lib.mkOption {
        type = lib.types.enum [ "ed25519" "rsa" "ecdsa" ];
        default = "ed25519";
        description = "SSH key type for new key generation.";
      };
      keyPath = lib.mkOption {
        type = lib.types.str;
        default = "~/.ssh/id_ed25519";
        description = "Default SSH key path (relative to home directory).";
      };
      addKeysToAgent = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Automatically add SSH keys to ssh-agent.";
      };
      forwardAgent = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable SSH agent forwarding (use with caution on shared systems).";
      };
      serverAliveInterval = lib.mkOption {
        type = lib.types.int;
        default = 60;
        description = "SSH keepalive interval in seconds (0 to disable). Prevents connection timeouts.";
      };
    };
  };

  tailnetHostSubmodule = lib.types.submodule {
    options = {
      ip = lib.mkOption {
        type = lib.types.str;
        description = "Stable Tailscale IP (100.x.x.x)";
        example = "100.64.1.5";
      };
      hostname = lib.mkOption {
        type = lib.types.str;
        description = "Short hostname as it appears in the tailnet";
        example = "homeserver";
      };
      magicDnsName = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Full MagicDNS name, e.g. homeserver.tail1234.ts.net";
      };
    };
  };
in
{
  imports = [ ../../config.nix ];

  options = {
    me = lib.mkOption {
      type = userSubmodule;
      description = "User identity information (username, email, SSH keys, etc.).";
    };

    preferences = lib.mkOption {
      type = preferencesSubmodule;
      default = { };
      description = "User interface and experience preferences (theme, fonts, shell, editor).";
    };

    defaults = lib.mkOption {
      type = defaultsSubmodule;
      default = { };
      description = "Default applications for common operations (browser, email, terminal).";
    };

    location = lib.mkOption {
      type = locationSubmodule;
      default = { };
      description = "Geographic location and timezone settings.";
    };

    git = lib.mkOption {
      type = gitSubmodule;
      default = { };
      description = "Git configuration defaults and preferences.";
    };

    ssh = lib.mkOption {
      type = sshSubmodule;
      default = { };
      description = "SSH client preferences and defaults.";
    };

    tailnet = lib.mkOption {
      type = lib.types.attrsOf tailnetHostSubmodule;
      default = { };
      description = "Known tailnet hosts, keyed by logical name.";
      example = lib.literalExpression ''
        {
          homeserver = { ip = "100.64.1.5"; hostname = "homeserver"; };
          laptop = { ip = "100.64.1.12"; hostname = "laptop"; };
        }
      '';
    };

    ollamaModels = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
      description = "Ollama language model configurations for local AI inference.";
    };
  };
}
