#!/usr/bin/env bash
# =============================================================================
# steamlink-deploy.sh — Create a bootable Steam Link USB with Tailscale
# =============================================================================
# Purpose: Wrapper around boot_disk_creator.sh from steamlink-archlinux project.
#          Creates a bootable Arch Linux USB for Valve Steam Link hardware,
#          optionally injecting a Tailscale auth key for auto mesh VPN join.
#
# Usage:
#   ./scripts/steamlink-deploy.sh -k <tailscale-key>
#   ./scripts/steamlink-deploy.sh --tailscale-key <tailscale-key>
#   ./scripts/steamlink-deploy.sh -h
# =============================================================================

set -euo pipefail

STEAMLINK_PROJECT="/home/seanc/Documents/github/steamlink-archlinux"
CREATOR_SCRIPT="$STEAMLINK_PROJECT/boot_disk_creator.sh"

# --- usage ----------------------------------------------------------------
usage() {
  echo "Usage: $0 [--tailscale-key KEY]"
  echo ""
  echo "Creates a bootable Arch Linux USB for Valve Steam Link."
  echo ""
  echo "Options:"
  echo "  -k, --tailscale-key KEY  Tailscale auth key for automatic mesh VPN setup"
  echo "                           Device will join your tailnet on first boot"
  echo "  -h, --help               Show this help message"
  exit 0
}

# --- parse args -----------------------------------------------------------
TAILSCALE_KEY=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -k|--tailscale-key)
      TAILSCALE_KEY="$2"
      shift 2
      ;;
    --tailscale-key=*)
      TAILSCALE_KEY="${1#*=}"
      shift
      ;;
    -h|--help)
      usage
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Usage: $0 [-k|--tailscale-key KEY]"
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

# --- validate steamlink project ------------------------------------------
if [[ ! -d "$STEAMLINK_PROJECT" ]]; then
  echo "Error: steamlink-archlinux project not found at:" >&2
  echo "  $STEAMLINK_PROJECT" >&2
  echo "Clone it first: git clone git@github.com:Cairnstew/steamlink-archlinux.git" >&2
  exit 1
fi

if [[ ! -f "$CREATOR_SCRIPT" ]]; then
  echo "Error: boot_disk_creator.sh not found at:" >&2
  echo "  $CREATOR_SCRIPT" >&2
  exit 1
fi

# --- build args for upstream script --------------------------------------
ARGS=()
if [[ -n "$TAILSCALE_KEY" ]]; then
  ARGS+=(--tailscale-key "$TAILSCALE_KEY")
fi

# --- run -----------------------------------------------------------------
echo "==> Steam Link USB Deploy"

cd "$STEAMLINK_PROJECT"
exec sudo "$CREATOR_SCRIPT" "${ARGS[@]}"
