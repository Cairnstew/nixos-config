#!/usr/bin/env bash
# join-iso.sh — download, reassemble, and verify a split NixOS build from GitHub Releases
#
# Usage (Linux/Mac):
#   bash <(curl -sL "https://github.com/Cairnstew/nixos-config/releases/download/iso-<host>/join-iso.sh") <host>
#
# Usage (PowerShell):
#   iex (iwr "https://github.com/Cairnstew/nixos-config/releases/download/iso-<host>/join-iso.sh").Content <host>
#
# Example:
#   bash <(curl -sL "https://github.com/Cairnstew/nixos-config/releases/download/iso-wsl/join-iso.sh") wsl

set -euo pipefail

HOST="${1:?Usage: $0 <host>}"
ISO_NAME="nixos-${HOST}.tar.gz"
REPO="Cairnstew/nixos-config"
TAG="iso-${HOST}"
API_URL="https://api.github.com/repos/${REPO}/releases/tags/${TAG}"
CHECKSUM_FILE="${ISO_NAME}.sha256"

# ---------------------------------------------------------------------------
# OS / terminal detection
# ---------------------------------------------------------------------------
detect_os() {
    case "$(uname -s 2>/dev/null)" in
        Linux*)   echo "linux" ;;
        Darwin*)  echo "mac" ;;
        MINGW*|MSYS*|CYGWIN*) echo "bash_windows" ;;
        *)
            # No uname — likely native PowerShell on Windows
            echo "powershell"
            ;;
    esac
}

OS=$(detect_os)
echo "==> Detected environment: ${OS}"

# ---------------------------------------------------------------------------
# PowerShell branch — relaunch self as a .ps1
# ---------------------------------------------------------------------------
if [[ "$OS" == "powershell" ]]; then
    echo "==> Relaunching in PowerShell..."
    pwsh -NoProfile -Command "
\$iso = 'nixos-${HOST}.tar.gz'
\$tag = '${TAG}'
\$repo = '${REPO}'
\$api  = \"https://api.github.com/repos/\$repo/releases/tags/\$tag\"

Write-Host '==> Fetching asset list...'
\$urls = (Invoke-RestMethod \$api).assets.browser_download_url

Write-Host '==> Downloading assets in parallel...'
\$jobs = \$urls | ForEach-Object {
    \$url = \$_
    \$file = Split-Path \$url -Leaf
    Start-Job { Invoke-WebRequest \$using:url -OutFile \$using:file }
}
\$jobs | Wait-Job | Receive-Job

Write-Host '==> Joining parts...'
\$parts = Get-ChildItem \"\$iso.part*\" | Sort-Object Name
\$out = [System.IO.File]::OpenWrite(\$iso)
foreach (\$part in \$parts) {
    Write-Host \"    Adding \$(\$part.Name)...\"
    \$in = [System.IO.File]::OpenRead(\$part.FullName)
    \$in.CopyTo(\$out)
    \$in.Close()
}
\$out.Close()

Write-Host '==> Verifying SHA256...'
\$expected = (Get-Content \"\$iso.sha256\" -Raw).Split(' ')[0].Trim()
\$actual   = (Get-FileHash \$iso -Algorithm SHA256).Hash.ToLower()
if (\$expected -eq \$actual) {
    Write-Host '==> OK - file is intact'
} else {
    Write-Host 'ERROR: checksum mismatch!'
    Remove-Item \$iso
    exit 1
}
"
    exit 0
fi

# ---------------------------------------------------------------------------
# Bash branch (Linux / Mac / Git Bash on Windows)
# ---------------------------------------------------------------------------

# --- Download ---
echo "==> Fetching asset list from: ${API_URL}"

if command -v jq &>/dev/null; then
    URLS=$(curl -s "$API_URL" | jq -r '.assets[].browser_download_url')
else
    URLS=$(curl -s "$API_URL" | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4)
fi

echo "==> Downloading assets in parallel..."
echo "$URLS" | xargs -P4 -n1 curl -L -O

# --- Join ---
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
echo "    Done. Size: $(du -sh "${ISO_NAME}" | cut -f1)"

# --- Verify ---
echo ""
if [[ -f "${CHECKSUM_FILE}" ]]; then
    echo "==> Verifying SHA-256 checksum..."
    if sha256sum --check "${CHECKSUM_FILE}"; then
        echo ""
        echo "==> OK — file is intact: ${ISO_NAME}"
    else
        echo ""
        echo "Error: checksum mismatch!" >&2
        rm -f "${ISO_NAME}"
        exit 1
    fi
else
    echo "Warning: no checksum file found — skipping verification." >&2
fi