#!/usr/bin/env bash
set -euo pipefail

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