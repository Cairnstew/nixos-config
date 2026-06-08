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

# Dispatcher for nixos-deploy deploy <subcommand> ...
# Subcommands: run, with-keys, test, wizard
# For top-level nixos-deploy commands (prepare, iso, tailscale, secrets), use dedicated recipes.
# e.g., just deploy run desktop
#       just deploy run desktop -- --addr nixos@nixos
#       just deploy with-keys desktop
# just deploy with-keys desktop -- --addr nixos@nixos
[group('deploy')]
deploy subcommand host *flags:
    nixos-deploy deploy {{ subcommand }} {{ host }} {{ flags }}

# Shorthand: just deploy-run <host> [addr] [-- extra-args]
# e.g., just deploy-run desktop
# just deploy-run server 192.168.1.100
[group('deploy')]
deploy-run host addr="nixos@nixos" *args:
    nixos-deploy deploy run {{ host }} --addr {{ addr }} --extra-args "{{ args }}"

# VM-test a host config via nixos-anywhere (no target machine, validates disko layout)
[group('deploy')]
deploy-test host:
    nixos-deploy deploy test {{ host }}

# Interactive deploy wizard: SSH into live ISO, pick/partition disk, install
[group('deploy')]
deploy-wizard host:
    nixos-deploy deploy wizard {{ host }}

# Deploy with stored host key injection + SSH identity key.
# Defaults addr to nixos@nixos (Tailscale MagicDNS on live ISO).
# e.g., just deploy-with-keys desktop
# just deploy-with-keys desktop nixos@100.x.x.x
[group('deploy')]
deploy-with-keys host addr="nixos@nixos" *args:
    sudo nixos-deploy deploy with-keys {{ host }} --addr {{ addr }} --extra-args "{{ args }}"

# Generate host SSH keypair + bootstrap instructions for a new machine
# See: nixos-deploy prepare --help
[group('deploy')]
prepare host:
    nixos-deploy prepare {{ host }}

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
