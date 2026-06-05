# Secrets Module

Agenix secrets managed via [agenix-manager](https://github.com/Cairnstew/agenix-manager) with flat `.age` files.

## Overview

Secrets are declared in `secrets-manifest.json` and automatically wired to `age.secrets.*` by the agenix-manager NixOS module. The encrypted `.age` files live flat (no subdirectories) in this directory.

## Accessing Secrets

```nix
# Check if secret exists before using
config.age.secrets ? "github-token"

# Get decrypted path
config.age.secrets."github-token".path  # → /run/agenix/github-token

# Override ownership (in consuming module)
age.secrets."github-token" = {
  owner = lib.mkForce "seanc";
  group = lib.mkForce "users";
};
```

## Adding a New Secret

### Via agenix-manager TUI:
```bash
nix develop .#secrets
agenix-manager new
```

### Via plain agenix:
```bash
agenix -e modules/nixos/secrets/<name>.age -r /etc/agenix/secrets.nix
```

Then add to `secrets-manifest.json`.

## Secret Catalog

| Secret name | Purpose |
|---|---|
| huggingface-token | HuggingFace API token |
| groq-token | Groq API token |
| clarifai-pat | Clarifai personal access token |
| deepinfra-key | DeepInfra API key |
| opencode-token | OpenCode API token |
| aws-cloud | AWS credentials |
| aws-ssh-key | AWS SSH private key |
| aws-ssh-pub-key | AWS SSH public key |
| aws-lab-ssh-key | AWS lab SSH key |
| gcloud-auth | GCloud authentication |
| github-token | GitHub personal access token |
| github-token-nixos-config | GitHub token for nixos-config repo |
| github-token-obsidian | GitHub token for Obsidian sync |
| nixos-config-cache-token | Cachix push token |
| windows-password | Windows dual-boot password |
| better-email-password | MCP better-email password |
| tailscale-authkey | Tailscale pre-auth key |
| tailscale-oauthkey | Tailscale OAuth client secret |
| tailscale-ssh-key | Tailscale SSH key |
| onepassword-token | 1Password service account token |

## Notes

- Ownership overrides are set in consuming modules via `config.age.secrets.<name>.owner`
- Always check `config.age.secrets ? "name"` before referencing a secret path
- CI builds disable agenix-manager via `{ agenixManager.enable = false; }` in `packages.nix`
