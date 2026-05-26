#!/usr/bin/env bash
# bootstrap.sh — First-time setup for a new NixOS install from this repo
#
# Usage:
#   ./scripts/bootstrap.sh [hostname]
#
# If you omit hostname you will be prompted for it.
#
# This script:
#   1. Sets the system hostname (requires sudo)
#   2. Runs `nix run` with the experimental features needed by flakes
#
# New install workflow (from README):
#   1. Install NixOS (or WSL)
#   2. git clone https://github.com/Cairnstew/nixos-config.git
#   3. Edit config.nix with your user information
#   4. Rename/adjust ./configurations/nixos/<hostname>/default.nix
#   5. Run this script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

# --- hostname -----------------------------------------------------------
HOSTNAME="${1:-}"

if [[ -z "$HOSTNAME" ]]; then
  read -r -p "Enter hostname for this machine: " HOSTNAME
  if [[ -z "$HOSTNAME" ]]; then
    echo "Error: hostname is required." >&2
    exit 1
  fi
fi

echo "==> Setting hostname to: $HOSTNAME"
sudo hostname "$HOSTNAME"

# write it so it survives reboot (most NixOS installs will have /etc/hostname)
echo "$HOSTNAME" | sudo tee /etc/hostname > /dev/null

echo ""
echo "==> Running: nix --extra-experimental-features 'nix-command flakes' run"
nix --extra-experimental-features "nix-command flakes" run
