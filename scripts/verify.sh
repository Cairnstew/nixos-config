#!/usr/bin/env bash
# =============================================================================
# verify.sh — Quick local verification script
# =============================================================================
# Purpose: Run lightweight checks without needing full CI or heavy builds.
#          This is a convenience wrapper around `nix run .#local-verify`
#
# Usage:
#   ./scripts/verify.sh        # Run all checks
#   ./scripts/verify.sh eval   # Just evaluation
#   ./scripts/verify.sh fmt    # Just formatting
#   ./scripts/verify.sh lint   # Just linting
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

# Check if we're in a nix environment
if ! command -v nix &> /dev/null; then
    echo "Error: nix command not found"
    echo "Please install Nix: https://nixos.org/download.html"
    exit 1
fi

# Run the flake app
echo "Running local verification..."
echo ""
nix run .#local-verify -- "$@"
