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
    nix run .#activate {{ host }}

# ── Fresh Install ────────────────────────────────────────────────────────────

# Deploy via nixos-anywhere using the per-host deploy wrapper.
# Auto-detects disko mode (disk-config.nix sidecar) and host key pre-provisioning.
# e.g., just deploy-run desktop nixos@nixos
#       just deploy-run server 192.168.1.100
[group('deploy')]
deploy-run host target *args:
    nix run .#deploy-{{ host }} -- {{ target }} {{ args }}

# Deploy desktop with existing partition layout (useExisting dualBoot mode).
# Auto-detects --disko-mode none from the host config.
# e.g., just deploy-desktop
#       just deploy-desktop nixos@100.x.x.x
[group('deploy')]
deploy-desktop target="nixos@nixos":
    nix run .#deploy-desktop -- {{ target }}

# ── ISO & Ventoy ─────────────────────────────────────────────────────────────

# Deploy ISOs + config to a Ventoy USB (auto-detect or specify device)
# e.g., just ventoy-deploy, just ventoy-deploy /dev/sdb, just ventoy-deploy --install /dev/sdb

ventoy-deploy *args:
    sudo rm -f /run/media/seanc/Ventoy/iso/linux/deploy.iso
    sudo nix run .#ventoy-deploy --impure -- {{ args }}

# Build the ventoy-bundle (all ISOs in a directory tree, no deploy)
ventoy-bundle:
    sudo nix build .#ventoy-bundle

# Build the Ventoy installer ISO (via live-iso system, auth key auto-generated at deploy time)
# Requires --impure because agenix-decrypted secrets live outside the Nix store.
ventoy-iso:
    sudo nix build .#live-iso-deploy --impure

# ── Testing ──────────────────────────────────────────────────────────────────

# List all testable hosts
test-list:
    nix run .#test list

# Run a VM test for a host (e.g., just test laptop)
test host:
    nix run .#test run {{ host }}

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
    sudo docker build -t {{ IMAGE }} -f modules/flake-parts/act-fixed.Dockerfile /tmp
    @echo "Built {{ IMAGE }} — ready to use with just act* commands"

# Test GitHub Actions workflows locally
# Usage: just act [job] [extra flags...]
# Default job: verify-local
# Note:
#   --bind avoids Docker 27+ "path escapes from parent" error.
#   -P pins ubuntu-latest to the fixed image (required with Docker 29+).
#   --action-offline-mode prevents pulling the fixed image (it's local-only).
# Prepend 'sudo --preserve-env=PATH' if Docker requires root.
act job="verify-local" *flags:
    act --bind -P ubuntu-latest={{ IMAGE }} --action-offline-mode -j {{ job }} -W .github/workflows/local-verify.yml {{ flags }}

# Run a specific single job (e.g., just act-eval, just act-format, just act-lint, just act-flake)
act-eval:
    act --bind -P ubuntu-latest={{ IMAGE }} --action-offline-mode -j eval-check -W .github/workflows/local-verify.yml

act-format:
    act --bind -P ubuntu-latest={{ IMAGE }} --action-offline-mode -j format-check -W .github/workflows/local-verify.yml

act-lint:
    act --bind -P ubuntu-latest={{ IMAGE }} --action-offline-mode -j lint-nix -W .github/workflows/local-verify.yml

act-flake:
    act --bind -P ubuntu-latest={{ IMAGE }} --action-offline-mode -j flake-check -W .github/workflows/local-verify.yml

# List available workflow jobs
act-list:
    act --bind -P ubuntu-latest={{ IMAGE }} --action-offline-mode --list -W .github/workflows/local-verify.yml
