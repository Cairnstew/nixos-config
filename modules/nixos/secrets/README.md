# Secrets

Agenix secrets management with declarative secret catalog.

## Overview

This module provides centralized secrets management using [agenix](https://github.com/ryantm/agenix).
It defines a catalog of secrets that are automatically declared as `age.secrets` when the module is enabled.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.secrets.enable` | `false` | Enable agenix secrets management |
| `my.secrets.catalog` | `{}` | Secret catalog (read-only, defined in module) |

### Secret Structure

Each secret in the catalog has:
- `name`: The agenix secret name (used for `age.secrets.<name>`)
- `file`: Path to the `.age` encrypted file
- `owner`: File owner (default: `"root"`)
- `group`: File group (default: `"root"`)
- `mode`: File permissions (default: `"0400"`)

## Usage Example

```nix
# In host configuration
my.secrets.enable = true;
```

Accessing secrets in other modules:

```nix
# Check if secret exists before using
config.age.secrets ? "github-token"

# Get secret path
config.age.secrets."github-token".path

# Get secret name from catalog
config.my.secrets.catalog.github.token.name  # returns "github-token"
```

## Adding New Secrets

1. Create the encrypted `.age` file in `secrets/<category>/<name>.age`
2. Add the secret definition to `secrets.nix` in this module
3. Reference the secret via `config.age.secrets.<name>.path` in consuming modules

## Secret Catalog

Secrets are organized by category:

| Category | Secrets |
|----------|---------|
| `ai` | huggingface-token, groq-token, clarifai-pat, deepinfra-key, opencode-token |
| `cloud/aws` | auth, ssh-key, ssh-pub-key, lab-ssh-key |
| `cloud/gcloud` | auth.json |
| `github` | github-token |
| `github/repos` | token-nixos-config, token-obsidian |
| `cachix` | nixos-config-cache-token |
| `tailscale` | authkey, apikey, ssh-key, cloud-authkey |

## Notes

- Secrets are only accessible when `my.secrets.enable = true`
- Always check `config.age.secrets ? "name"` before referencing a secret
- The `secrets.nix` file in this module defines the complete secret catalog
- Encrypted secret files are stored in the `secrets/` directory at flake root
