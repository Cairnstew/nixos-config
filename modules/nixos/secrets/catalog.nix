# modules/nixos/secrets/catalog.nix
# Secret catalog definition — single source of truth for available secrets
#
# The agenix name (used as age.secrets.<name>) is derived automatically from the
# filename stem. For example: /secrets/ai/huggingface-token.age → "huggingface-token"
#
# To add a new secret:
#   1. Create the encrypted .age file: nix run .#secrets-edit ai/my-new-token.age
#   2. Add a catalog entry below with the logical path and fileRel
#   3. Run: nix run .#secrets-generate -- --write
#   4. Reference in consuming modules via config.age.secrets.<name>.path
{ flake, lib, ... }:
let
  self = flake.inputs.self;
  me = flake.config.me;

  # Helper to create a secret definition
  # Usage: secret "/path/to/file.age" { owner = "user"; }
  # The agenix name is derived from the filename stem (without .age)
  secret = fileRel: extra: {
    inherit fileRel;
    name = lib.removeSuffix ".age" (builtins.baseNameOf fileRel);
    file = self + fileRel;
    owner = extra.owner or "root";
    group = extra.group or "root";
    mode = extra.mode or "0400";
  };
in
{
  secretsCatalog = {
    # AI Services
    "ai.huggingface.token" = secret "/secrets/ai/huggingface-token.age" { owner = me.username; };
    "ai.groq.token" = secret "/secrets/ai/groq-token.age" { owner = me.username; };
    "ai.clarifai.pat" = secret "/secrets/ai/clarifai-pat.age" { owner = me.username; };
    "ai.deepinfra.key" = secret "/secrets/ai/deepinfra-key.age" { owner = me.username; };
    "ai.opencode.token" = secret "/secrets/ai/opencode-token.age" { owner = me.username; };

    # Cloud Providers
    "cloud.aws.auth" = secret "/secrets/cloud/aws/aws-cloud.age" { owner = me.username; };
    "cloud.aws.sshKey" = secret "/secrets/cloud/aws/aws-ssh-key.age" { owner = me.username; };
    "cloud.aws.sshPubKey" = secret "/secrets/cloud/aws/aws-ssh-pub-key.age" { owner = me.username; };
    "cloud.aws.labs.sshKey" = secret "/secrets/cloud/aws/aws-lab-ssh-key.age" { owner = me.username; };
    "cloud.gcloud.auth" = secret "/secrets/cloud/gcloud/gcloud-auth.age" { owner = me.username; };

    # GitHub
    "github.token" = secret "/secrets/github/github-token.age" { owner = me.username; group = "users"; };
    "github.repos.nixosConfig" = secret "/secrets/github/repos/github-token-nixos-config.age" { owner = me.username; };
    "github.repos.obsidian" = secret "/secrets/github/repos/github-token-obsidian.age" { owner = me.username; };

    # Cachix
    "system.cache" = secret "/secrets/cachix/nixos-config-cache-token.age" { owner = "root"; };

    # Windows Dual-Boot
    "windows.password" = secret "/secrets/windows-password.age" { owner = "root"; };

    # MCP Servers
    "mcp.better-email.password" = secret "/secrets/mail/gmail/better-email-password.age" { owner = me.username; };

    # Tailscale
    "tailscale.authKey" = secret "/secrets/tailscale/tailscale-authkey.age" { owner = me.username; };
    "tailscale.oauthKey" = secret "/secrets/tailscale/tailscale-oauthkey.age" { owner = me.username; };
    "tailscale.sshKey" = secret "/secrets/tailscale/tailscale-ssh-key.age" { owner = me.username; };

  };
}
