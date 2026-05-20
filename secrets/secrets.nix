# =============================================================================
# secrets.nix — Agenix Secret Definitions
# =============================================================================
# Purpose: Declares all encrypted secrets for the flake, specifying which SSH
#          keys can decrypt each secret.
#
# Encryption: Use `agenix -e secrets/<path>.age` to edit secrets.
# Decryption: Secrets are decrypted at activation time via agenix.
#
# Key Sources:
#   - User keys: config.me.sshKey (ed25519 public key)
#   - Host keys: Generated at install, stored in /etc/ssh/
#
# Note: When adding a new host or user, regenerate all .age files to include
#       the new public key.
# =============================================================================

let
  config = import ../config.nix;
  users = [ config.me.sshKey ];

  # SSH host keys for decrypting secrets on each machine
  laptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIETE96NnwPAZ0n5y6XcCzoErkrAhulUht/Hho0V829Qy root@laptop";
  server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINJXLC3S2pEuIchrWMtmWiTaJOA+U02HVyRczRNbRjMX root@nixos";
  wsl = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAKZIYbM8ac+hHEAvvScLq2lHtAHi44Zlvlew/QYU3H0 root@wsl";

  # All systems that should decrypt secrets
  systems = [ laptop server wsl ];
  # Combined: user key + all system keys
  all = users ++ systems;
in
{
  # -----------------------------------------------------------------------------
  # GitHub Tokens
  # -----------------------------------------------------------------------------
  # Service: GitHub API authentication (gh CLI, git operations, API calls)
  # Hosts: All (laptop, server, wsl)
  # Keys: User + all systems
  "github/github-token.age".publicKeys = all;

  # Service: GitHub fine-grained PAT for nixos-config repository
  # Hosts: All (for CI, automated updates)
  # Keys: User + all systems
  "github/repos/token-nixos-config.age".publicKeys = all;

  # Service: GitHub fine-grained PAT for obsidian repository
  # Hosts: All
  # Keys: User + all systems
  "github/repos/token-obsidian.age".publicKeys = all;

  # -----------------------------------------------------------------------------
  # Binary Cache (Cachix)
  # -----------------------------------------------------------------------------
  # Service: Cachix authentication token for pushing to nixos-config-cache
  # Hosts: Build machines (laptop, server)
  # Keys: User + all systems
  # Note: Only needed on hosts that push to the cache
  "cachix/nixos-config-cache-token.age".publicKeys = all;

  # -----------------------------------------------------------------------------
  # Tailscale Authentication
  # -----------------------------------------------------------------------------
  # Service: Tailscale node auth key for automatic enrollment
  # Hosts: All new installations
  # Keys: User + all systems
  # Expires: 90 days from creation (created 2026-03-23)
  "tailscale/authkey.age".publicKeys = all;

  # Service: Tailscale API key for programmatic management
  # Hosts: Server (for automation scripts)
  # Keys: User + all systems
  "tailscale/apikey.age".publicKeys = all;

  # Service: Tailscale SSH key for machine-to-machine auth
  # Hosts: All
  # Keys: User + all systems
  "tailscale/ssh-key.age".publicKeys = all;

  # Service: Cloud-specific Tailscale auth key (longer expiry)
  # Hosts: Cloud VMs
  # Keys: User + all systems
  # Expires: 2026-08-14
  "tailscale/cloud-authkey.age".publicKeys = all;

  # -----------------------------------------------------------------------------
  # 1Password
  # -----------------------------------------------------------------------------
  # Service: 1Password CLI authentication token
  # Hosts: User machines only (laptop, desktop) - not servers
  # Keys: User key only (not shared to servers)
  # Note: This is a user secret, not a system secret
  "onepassword-token.age".publicKeys = users;

  # -----------------------------------------------------------------------------
  # Cloud Providers
  # -----------------------------------------------------------------------------
  # Service: AWS authentication (access key + secret)
  # Hosts: Server (primary), laptop (development)
  # Keys: User + all systems
  "cloud/aws/auth.age".publicKeys = all;

  # Service: AWS SSH private key for EC2 access
  # Hosts: All (for connecting to AWS instances)
  # Keys: User + all systems
  "cloud/aws/ssh-key.age".publicKeys = all;

  # Service: AWS SSH public key (for instance metadata)
  # Hosts: All
  # Keys: User + all systems
  "cloud/aws/ssh-pub-key.age".publicKeys = all;

  # Service: AWS SSH key for lab environment
  # Hosts: Server (lab management)
  # Keys: User + all systems
  "cloud/aws/lab-ssh-key.age".publicKeys = all;

  # Service: Google Cloud service account key (JSON)
  # Hosts: Server (primary), laptop (development)
  # Keys: User + all systems
  "cloud/gcloud/auth.json.age".publicKeys = all;

  # -----------------------------------------------------------------------------
  # AI/ML Services
  # -----------------------------------------------------------------------------
  # Service: Hugging Face API token (for model downloads)
  # Hosts: Server (with GPU), laptop
  # Keys: User + all systems
  "ai/huggingface-token.age".publicKeys = all;

  # Service: Groq API key (fast LLM inference)
  # Hosts: All (for aider, coding assistants)
  # Keys: User + all systems
  "ai/groq-token.age".publicKeys = all;

  # Service: Clarifai Personal Access Token
  # Hosts: Server (ML workloads)
  # Keys: User + all systems
  "ai/clarifai-pat.age".publicKeys = all;

  # Service: DeepInfra API key (model hosting)
  # Hosts: Server
  # Keys: User + all systems
  "ai/deepinfra-key.age".publicKeys = all;

  # Service: Opencode API token (AI assistant)
  # Hosts: All development machines
  # Keys: User + all systems
  "ai/opencode-token.age".publicKeys = all;

}
