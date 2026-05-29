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

# Deploy a NixOS host via nixos-anywhere (fresh install)
# Usage: just deploy <hostname> <ssh-address> [-- nixos-anywhere flags]
# Examples:
#   just deploy server 192.168.1.100         # root@ (after initial install)
#   just deploy desktop nixos@192.168.1.100  # nixos@ (from NixOS installer ISO)
# Prerequisites: Nix with flakes, SSH access to target
# Flake output: apps.deploy (calls nixos-anywhere)
[group('deploy')]
deploy host ip *args:
    nix run .#deploy -- {{host}} {{ip}} {{args}}

# Register a freshly deployed host with agenix
# Connects via SSH, fetches host key, prints instructions
# Usage: just register-host <hostname> <ssh-address>
# Examples:
#   just register-host server 192.168.1.100
#   just register-host desktop 192.168.1.100
# Prerequisites: SSH access to target as root
[group('deploy')]
register-host host ip:
    @echo "Fetching SSH host key for {{host}}..."
    KEY=$$(ssh "root@{{ip}}" "cat /etc/ssh/ssh_host_ed25519_key.pub")
    @echo ""
    @echo "Host key for {{host}}:"
    @echo "  $$KEY"
    @echo ""
    @echo "Next steps:"
    @echo "  1. Add this key to secrets/secrets.nix under {{host}}'s recipients"
    @echo "  2. Run: agenix -r"
    @echo "  3. Rebuild: nix run .#deploy -- {{host}} {{ip}}"

# Build a custom NixOS installer ISO with Tailscale auto-connect
# Builds to ./ISO/nixos-installer.iso
# Usage: just build-iso
# Prerequisites: Nix with flakes, agenix (for tailscale key decryption)
# Flake output: apps.build-iso (calls nixos-anywhere)
[group('deploy')]
build-iso:
    nix run .#build-iso

# Build installer ISO and deploy to Ventoy USB
# Usage: just deploy-iso <ventoy-mount-point>
# Example: just deploy-iso /run/media/{{user}}/VENTOY
# Prerequisites: Ventoy USB mounted at <ventoy-mount-point>
[group('deploy')]
deploy-iso mount="":
    nix run .#build-iso
    @echo "Copying ISO to {{mount}}/ISO/..."
    mkdir -p "{{mount}}/ISO"
    cp ISO/nixos-installer.iso "{{mount}}/ISO/"
    @echo "Done! Add ventoy/ventoy.json to {{mount}}/ for auto-boot config."

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
