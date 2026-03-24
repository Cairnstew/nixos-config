#!/usr/bin/env bash
# join-iso.sh — reassemble a split NixOS ISO downloaded from GitHub Releases
#
# Usage:
#   bash join-iso.sh <iso-filename>
#
# Example:
#   bash join-iso.sh nixos-iso-server.iso
#
# Place all <iso-filename>.part* files and the .sha256 file in the same directory.

set -euo pipefail

ISO_NAME="${1:?Usage: $0 <iso-filename>}"
CHECKSUM_FILE="${ISO_NAME}.sha256"

echo "==> Locating segments for: ${ISO_NAME}"

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

if [[ -f "${CHECKSUM_FILE}" ]]; then
  echo "==> Verifying SHA-256 checksum..."
  if sha256sum --check "${CHECKSUM_FILE}"; then
    echo ""
    echo "==> OK — ISO is intact: ${ISO_NAME}"
  else
    echo ""
    echo "Error: checksum mismatch!" >&2
    rm -f "${ISO_NAME}"
    exit 1
  fi
else
  echo "Warning: no checksum file found — skipping verification." >&2
fi