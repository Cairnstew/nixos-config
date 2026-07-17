{ inputs, ... }: {
  perSystem = { pkgs, system, ... }:
    let
      src = inputs.steamlink-archlinux;
      creatorScript = "${src}/boot_disk_creator.sh";
    in
    {
      apps.steamlink-deploy = {
        type = "app";
        program = pkgs.writeShellApplication {
          name = "steamlink-deploy";
          runtimeInputs = [ pkgs.bash pkgs.coreutils pkgs.curl pkgs.gnutar pkgs.gnused ];
          text = ''
            set -euo pipefail

            CREATOR_SCRIPT="${creatorScript}"

            TAILSCALE_KEY=""
            DEVICE=""
            while [[ $# -gt 0 ]]; do
              case "$1" in
                -k|--tailscale-key)
                  TAILSCALE_KEY="$2"
                  shift 2
                  ;;
                --tailscale-key=*)
                  TAILSCALE_KEY="''${1#*=}"
                  shift
                  ;;
                -d|--device)
                  DEVICE="$2"
                  shift 2
                  ;;
                --device=*)
                  DEVICE="''${1#*=}"
                  shift
                  ;;
                -h|--help)
                  echo "Usage: steamlink-deploy [OPTIONS]"
                  echo ""
                  echo "Creates a bootable Arch Linux USB for Valve Steam Link."
                  echo ""
                  echo "Options:"
                  echo "  -d, --device DEV         USB partition (e.g. /dev/sdb1)"
                  echo "  -k, --tailscale-key KEY  Tailscale auth key (optional; falls back to agenix)"
                  echo "  -h, --help               Show this help"
                  echo ""
                  echo "If --tailscale-key is omitted, reads from /run/agenix/tailscale-authkey."
                  exit 0
                  ;;
                *)
                  break
                  ;;
              esac
            done

            # Auto-detect agenix Tailscale auth key
            if [[ -z "$TAILSCALE_KEY" && -f "/run/agenix/tailscale-authkey" ]]; then
              TAILSCALE_KEY="$(cat /run/agenix/tailscale-authkey 2>/dev/null || true)"
              if [[ -n "$TAILSCALE_KEY" ]]; then
                echo "=> Using Tailscale auth key from agenix"
              fi
            fi

            ARGS=()
            if [[ -n "$DEVICE" ]]; then
              ARGS+=(--device "$DEVICE")
            fi
            if [[ -n "$TAILSCALE_KEY" ]]; then
              ARGS+=(--tailscale-key "$TAILSCALE_KEY")
            fi

            # Ensure /tmp is writeable for curl downloads inside the script
            export TMPDIR="$(mktemp -d)"
            trap 'rm -rf "$TMPDIR"' EXIT

            exec bash "$CREATOR_SCRIPT" "''${ARGS[@]}"
          '';
        };
      };
    };
}
