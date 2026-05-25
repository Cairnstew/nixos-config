# modules/nixos/secrets/catalog.nix
# Secret catalog definition - pure data, no config logic
{ flake, lib, ... }:
let
  self = flake.inputs.self;
  me = flake.config.me;

  # Helper to create a secret definition
  # Usage: secret "name" "/path/to/file.age" { owner = "user"; }
  secret = name: file: extra: {
    inherit name;
    file = self + file;
    owner = extra.owner or "root";
    group = extra.group or "root";
    mode = extra.mode or "0400";
  };
in
{
  # ── Secret Catalog ──────────────────────────────────────────────────────────
  # This attrset defines all available secrets. Each entry maps a logical path
  # to a secret definition containing the agenix name, file path, and permissions.
  #
  # To add a new secret:
  # 1. Create the encrypted .age file in secrets/<path>
  # 2. Add an entry below with the logical path as the key
  # 3. Reference via config.age.secrets.<name>.path in consuming modules

  secretsCatalog = {
    # AI Services
    "ai.huggingface.token" = secret "huggingface-token" "/secrets/ai/huggingface-token.age" { owner = me.username; };
    "ai.groq.token" = secret "groq-token" "/secrets/ai/groq-token.age" { owner = me.username; };
    "ai.clarifai.pat" = secret "clarifai-pat" "/secrets/ai/clarifai-pat.age" { owner = me.username; };
    "ai.deepinfra.key" = secret "deepinfra-key" "/secrets/ai/deepinfra-key.age" { owner = me.username; };
    "ai.opencode.token" = secret "opencode-token" "/secrets/ai/opencode-token.age" { owner = me.username; };

    # Cloud Providers
    "cloud.aws.auth" = secret "aws-cloud" "/secrets/cloud/aws/auth.age" { owner = me.username; };
    "cloud.aws.sshKey" = secret "aws-cloud-ssh-key" "/secrets/cloud/aws/ssh-key.age" { owner = me.username; };
    "cloud.aws.sshPubKey" = secret "aws-cloud-ssh-pub-key" "/secrets/cloud/aws/ssh-pub-key.age" { owner = me.username; };
    "cloud.aws.labs.sshKey" = secret "aws-lab-ssh-key" "/secrets/cloud/aws/lab-ssh-key.age" { owner = me.username; };
    "cloud.gcloud.auth" = secret "gcloud-auth" "/secrets/cloud/gcloud/auth.json.age" { owner = me.username; };

    # GitHub
    "github.token" = secret "github-token" "/secrets/github/github-token.age" { owner = me.username; group = "users"; };
    "githubRepos.nixosConfig" = secret "github-token-nixos-config" "/secrets/github/repos/token-nixos-config.age" { owner = me.username; };
    "githubRepos.obsidian" = secret "github-token-obsidian" "/secrets/github/repos/token-obsidian.age" { owner = me.username; };

    # Cachix
    "system.cache" = secret "nixos-config-cache-token" "/secrets/cachix/nixos-config-cache-token.age" { owner = "root"; };

    # Windows Dual-Boot
    "windows.password" = secret "windows-password" "/secrets/windows-password.age" { owner = "root"; };

    # Tailscale
    "tailscale.authKey" = secret "tailscale-authkey" "/secrets/tailscale/authkey.age" { owner = me.username; };
    "tailscale.apiKey" = secret "tailscale-apikey" "/secrets/tailscale/apikey.age" { owner = me.username; };
    "tailscale.sshKey" = secret "tailscale-ssh-key" "/secrets/tailscale/ssh-key.age" { owner = me.username; };
    "tailscale.cloudAuth" = secret "tailscale-cloud-auth" "/secrets/tailscale/cloud-authkey.age" { owner = me.username; };
  };
}
