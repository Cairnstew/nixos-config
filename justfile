default:
    @just --list

# ── Flake Management ─────────────────────────────────────────────────────────

# Update all flake inputs and commit lockfile
update:
    nix run .#update

# Check flake evaluation (no build)
check:
    nix flake check --no-build

# Format all Nix files
fmt:
    nix fmt

# ── Activation ───────────────────────────────────────────────────────────────

# Activate local configuration
local:
    nix run

# Remotely activate a host over SSH (e.g., just activate laptop)
[group('deploy')]
activate host:
    nix run .#activate {{host}}

# ── Fresh Install ────────────────────────────────────────────────────────────

# Deploy a NixOS host via nixos-anywhere (fresh install)
# e.g., just deploy server 192.168.1.100
[group('deploy')]
deploy host ip *args:
    nix run .#deploy -- {{host}} {{ip}} {{args}}

# Register a freshly deployed host with agenix (e.g., just register-host server 192.168.1.100)
[group('deploy')]
register-host host ip:
    @echo "Fetching SSH host key for {{host}}..."
    KEY=$$(ssh "root@{{ip}}" "cat /etc/ssh/ssh_host_ed25519_key.pub")
    @echo ""
    @echo "Host key for {{host}}:  $$KEY"
    @echo ""
    @echo "Next: add this key to secrets/secrets.nix, run 'agenix -r', then rebuild."

# Deploy via Tailscale MagicDNS (installer ISO hostname is "nixos")
[group('deploy')]
deploy-tailscale host *args:
    nix run .#deploy -- {{host}} nixos@nixos.tail685690.ts.net {{args}}

# Register host key via Tailscale MagicDNS
[group('deploy')]
register-host-tailscale host:
    just register-host {{host}} nixos.tail685690.ts.net

# Interactive deploy wizard: SSH into live ISO, pick/partition disk, install
[group('deploy')]
deploy-wizard host:
    nix run .#deploy-wizard -- {{host}}

# ── ISO & Ventoy ─────────────────────────────────────────────────────────────

# Deploy ISOs + config to a Ventoy USB (auto-detect or specify device)
# e.g., just ventoy-deploy, just ventoy-deploy /dev/sdb, just ventoy-deploy --install /dev/sdb
[group('deploy')]
ventoy-deploy *args:
    nix run .#ventoy-deploy -- {{args}}

# Build the ventoy-bundle (all ISOs in a directory tree, no deploy)
ventoy-bundle:
    nix build .#ventoy-bundle

# Build the Ventoy installer ISO (put your ephemeral Tailscale key in modules/flake-parts/ventoy/ts.key)
ventoy-iso:
    nix build .#ventoy-installer-iso

# ── Testing ──────────────────────────────────────────────────────────────────

# List all testable hosts
test-list:
    nix run .#test list

# Run a VM test for a host (e.g., just test laptop)
test host:
    nix run .#test run {{host}}

# ── Maintenance ──────────────────────────────────────────────────────────────

# Clean old generations and EFI boot entries
fuckboot:
    sudo nix-collect-garbage -d
    sudo /run/current-system/bin/switch-to-configuration boot

# ── CI / Act ─────────────────────────────────────────────────────────────────

IMAGE := "act-fixed:latest"

# Build the fixed Docker image (workaround for Docker 29+ "mkdirat var/run" bug)
# The catthehacker/ubuntu:act-latest image has /var/run -> /run as a symlink,
# which causes docker cp to fail with "mkdirat var/run: file exists".
# This image replaces it with a real directory.
act-image:
    sudo docker build -t {{IMAGE}} -f modules/flake-parts/act-fixed.Dockerfile /tmp
    @echo "Built {{IMAGE}} — ready to use with just act* commands"

# Test GitHub Actions workflows locally
# Usage: just act [job] [extra flags...]
# Default job: verify-local
# Note:
#   --bind avoids Docker 27+ "path escapes from parent" error.
#   -P pins ubuntu-latest to the fixed image (required with Docker 29+).
#   --action-offline-mode prevents pulling the fixed image (it's local-only).
# Prepend 'sudo --preserve-env=PATH' if Docker requires root.
act job="verify-local" *flags:
    act --bind -P ubuntu-latest={{IMAGE}} --action-offline-mode -j {{job}} -W .github/workflows/local-verify.yml {{flags}}

# Run a specific single job (e.g., just act-eval, just act-format, just act-lint, just act-flake)
act-eval:
    act --bind -P ubuntu-latest={{IMAGE}} --action-offline-mode -j eval-check -W .github/workflows/local-verify.yml

act-format:
    act --bind -P ubuntu-latest={{IMAGE}} --action-offline-mode -j format-check -W .github/workflows/local-verify.yml

act-lint:
    act --bind -P ubuntu-latest={{IMAGE}} --action-offline-mode -j lint-nix -W .github/workflows/local-verify.yml

act-flake:
    act --bind -P ubuntu-latest={{IMAGE}} --action-offline-mode -j flake-check -W .github/workflows/local-verify.yml

# List available workflow jobs
act-list:
    act --bind -P ubuntu-latest={{IMAGE}} --action-offline-mode --list -W .github/workflows/local-verify.yml
