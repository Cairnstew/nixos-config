# Show all available recipes (default)
# Usage: just
# Prerequisites: just (command runner)
default:
    @just --list

# Update all flake inputs and commit lockfile
# Usage: just update
# Prerequisites: Nix with flakes enabled
# Flake output: .#update (nixos-unified primary-inputs update)
update:
    nix run .#update

# Deploy configuration to Beelink (pureintent host)
# Usage: just pureintent
# Prerequisites: SSH access to pureintent, Nix with flakes
# Flake output: nixosConfigurations.pureintent (remote deployment)
[group('deploy')]
pureintent:
    nix run . pureintent

# Deploy configuration to infinitude (macOS host)
# Usage: just infinitude
# Prerequisites: SSH access to infinitude, nix-darwin
# Flake output: darwinConfigurations.infinitude (remote deployment)
[group('deploy')]
infinitude:
    nix run . infinitude

# Run all pre-commit hooks on all files
# Usage: just pca
# Prerequisites: pre-commit installed, .pre-commit-config.yaml exists
pca:
    pre-commit run --all-files

# Clean up old generations and EFI boot entries
# Usage: just fuckboot
# Prerequisites: root access (sudo), NixOS
# See: https://discourse.nixos.org/t/why-doesnt-nix-collect-garbage-remove-old-generations-from-efi-menu/17592/4
fuckboot:
    sudo nix-collect-garbage -d
    sudo /run/current-system/bin/switch-to-configuration boot

# Activate local configuration (build and switch current host)
# Usage: just local
# Prerequisites: Running on a NixOS/nix-darwin host with this flake
# Flake output: packages.default (activate script)
# Note: For faster builds, use `just nom local` (if nom output is configured)
local:
    nix run

# Test GitHub Actions workflows locally with act
# Usage: just act [job]
# Prerequisites: act (available in devShell)
# Default job: verify-local
# Jobs: verify-local, eval-check, format-check, lint-nix, flake-check
act job="verify-local":
    act -j {{job}} -W .github/workflows/local-verify.yml

# List all workflow jobs available for local testing with act
# Usage: just act-list
act-list:
    act --list -W .github/workflows/local-verify.yml
