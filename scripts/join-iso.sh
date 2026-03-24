#!/usr/bin/env bash
# join-iso.sh — reassemble a split NixOS ISO downloaded from GitHub Releases
#
# Usage:
#   bash join-iso.sh <iso-filename>
#
# Example:
#   bash join-iso.sh nixos-24.11-my-host-x86_64-linux.iso
#
# Place all  <iso>.part* files and the .sha256 file in the same directory
# as this script (or cd into that directory first).

set -euo pipefail

ISO_NAME="${1:?Usage: $0 <iso-filename>}"
CHECKSUM_FILE="${ISO_NAME}.sha256"

echo "==> Locating segments for: ${ISO_NAME}"

# Collect all matching part files, sorted numerically
mapfile -t PARTS < <(ls "${ISO_NAME}.part"* 2>/dev/null | sort -V)

if [[ ${#PARTS[@]} -eq 0 ]]; then
  echo "Error: no files matching '${ISO_NAME}.part*' found in $(pwd)" >&2
  exit 1
fi

echo "    Found ${#PARTS[@]} segment(s):"
for p in "${PARTS[@]}"; do
  printf "      %s  (%s)\n" "$p" "$(du -sh "$p" | cut -f1)"
done

echo ""
echo "==> Joining segments → ${ISO_NAME}"
cat "${PARTS[@]}" > "${ISO_NAME}"

echo "    Done. ISO size: $(du -sh "${ISO_NAME}" | cut -f1)"
echo ""

# Verify checksum if available
if [[ -f "${CHECKSUM_FILE}" ]]; then
  echo "==> Verifying SHA-256 checksum..."
  if sha256sum --check "${CHECKSUM_FILE}"; then
    echo ""
    echo "==> OK — ISO is intact: ${ISO_NAME}"
  else
    echo ""
    echo "Error: checksum mismatch! The ISO may be corrupted or a segment is missing." >&2
    rm -f "${ISO_NAME}"
    exit 1
  fi
else
  echo "Warning: no checksum file (${CHECKSUM_FILE}) found — skipping verification." >&2
  echo "         Download it from the release assets and re-run to verify."
fi