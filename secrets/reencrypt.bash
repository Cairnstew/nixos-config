#!/usr/bin/env bash
set -euo pipefail

# Add account if none configured
if ! op account list &>/dev/null || [ -z "$(op account list)" ]; then
    echo "No 1Password accounts configured, adding one..."
    op account add
fi

# Sign in if not already
if ! op account get &>/dev/null; then
    eval $(op signin)
fi

# Write key to temp file
TMPKEY=$(mktemp)
trap "rm -f $TMPKEY" EXIT

op read "op://Private/Nixos/private key" > "$TMPKEY"
chmod 600 "$TMPKEY"

nix run github:ryantm/agenix -- -r -i "$TMPKEY"