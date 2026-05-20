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
