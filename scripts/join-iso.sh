#!/usr/bin/env bash
# join-iso.sh — download, reassemble, and verify a split NixOS build from GitHub Releases
#
# Usage (Linux/Mac):
#   bash <(curl -sL "https://github.com/Cairnstew/nixos-config/releases/download/iso-<host>/join-iso.sh") <host>

set -euo pipefail

HOST="${1:?Usage: $0 <host>}"
REPO="Cairnstew/nixos-config"
TAG="iso-${HOST}"
API_URL="https://api.github.com/repos/${REPO}/releases/tags/${TAG}"

# --- Download ---
echo "==> Fetching asset list from: ${API_URL}"

if command -v jq &>/dev/null; then
    URLS=$(curl -s "$API_URL" | jq -r '.assets[].browser_download_url')
else
    URLS=$(curl -s "$API_URL" | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4)
fi

echo "==> Downloading assets in parallel..."
echo "$URLS" | xargs -P4 -n1 curl -L -O

# --- Detect output type ---
FILE_BASE="nixos-${HOST}"
CHECKSUM_FILE=$(ls "${FILE_BASE}".*.sha256 2>/dev/null | head -1 || true)

if [[ -z "$CHECKSUM_FILE" ]]; then
    echo "Error: no checksum file (${FILE_BASE}.*.sha256) found" >&2
    exit 1
fi

FILE_EXT="${CHECKSUM_FILE%.sha256}"
FILE_NAME="${FILE_EXT}"

# --- Join ---
echo "==> Locating segments for: ${FILE_NAME}"
# shellcheck disable=SC2206
mapfile -t PARTS < <(ls "${FILE_NAME}.part"* 2>/dev/null | sort -V)

if [[ ${#PARTS[@]} -eq 0 ]]; then
    echo "Error: no files matching '${FILE_NAME}.part*' found in $(pwd)" >&2
    exit 1
fi

echo "    Found ${#PARTS[@]} segment(s):"
for p in "${PARTS[@]}"; do
    printf "      %s  (%s)\n" "$p" "$(du -sh "$p" | cut -f1)"
done

echo ""
echo "==> Joining segments → ${FILE_NAME}"
cat "${PARTS[@]}" > "${FILE_NAME}"
echo "    Done. Size: $(du -sh "${FILE_NAME}" | cut -f1)"

# --- Verify ---
echo ""
echo "==> Verifying SHA-256 checksum..."
if sha256sum --check "${CHECKSUM_FILE}"; then
    echo ""
    echo "==> OK — file is intact: ${FILE_NAME}"
else
    echo ""
    echo "Error: checksum mismatch!" >&2
    rm -f "${FILE_NAME}"
    exit 1
fi