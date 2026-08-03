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
| alert-gmail | Gmail app password for SMTP email alerts |
| aws-cloud | AWS credentials |
| aws-lab-ssh-key | AWS lab SSH key |
| aws-ssh-key | AWS SSH private key |
| aws-ssh-pub-key | AWS SSH public key |
| clarifai-pat | Clarifai personal access token |
| deepinfra-key | DeepInfra API key |
| discord-auth | Discord token for Endcord profiles |
| gcloud-auth | GCloud authentication |
| github-token | GitHub personal access token |
| github-token-nixos-config | GitHub token for nixos-config repo |
| github-token-obsidian | GitHub token for Obsidian sync |
| google-calendar-oauth | Google Calendar OAuth for the MCP server |
| groq-token | Groq API token |
| huggingface-token | HuggingFace API token |
| live-iso-ssh-key | Plaintext age private key for decrypting tailscale auth at boot |
| mcp-better-email-password | MCP better-email password |
| neko-admin-password | Neko admin password (NEKO_MEMBER_MULTIUSER_ADMIN_PASSWORD) |
| neko-user-password | Neko user password (NEKO_MEMBER_MULTIUSER_USER_PASSWORD) |
| nixos-config-cache-token | Cachix push token |
| onepassword-token | 1Password service account token — has an `.age` file but is **not** in `secrets-manifest.json` (not wired to `age.secrets.*`) |
| opencode-token | OpenCode API token |
| resemble-ai-token | Resemble.ai TTS API token |
| speed-cd-password | SpeedCD indexer password |
| spotify-cred | Spotify credentials |
| squid-htpasswd | Squid proxy basic-auth htpasswd |
| suwayomi-password | Suwayomi basic-auth password |
| tailscale-authkey | Tailscale pre-auth key |
| tailscale-live-key | Tailscale temporary live environment key |
| tailscale-oauthkey | Tailscale OAuth client secret |
| ttyd-password | ttyd terminal web UI password |
| windows-password | Windows dual-boot password |

## Notes

- Ownership overrides are set in consuming modules via `config.age.secrets.<name>.owner`
- Always check `config.age.secrets ? "name"` before referencing a secret path
- CI package builds do **not** disable agenix-manager. `modules/flake-parts/packages.nix` only forces `services.tailscale.enable = false` and `services.tailscale-manager.enable = false` so package builds evaluate without tailscale. The committed `.age` files evaluate fine in CI.
- `secrets-manifest.json` is the source of truth (31 secrets). `onepassword-token` has an `.age` file but is **not** listed in the manifest — it is not wired to `age.secrets.*`.

## Related Modules

- **Imported by** [`modules/nixos/common.nix`](../common.nix) — enabled on all hosts via `my.*` options.
