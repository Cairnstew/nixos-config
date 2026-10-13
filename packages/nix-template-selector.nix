# =============================================================================
# nix-template-selector.nix — Interactive Nix Template Selector
# =============================================================================
# Purpose: Lists and initializes project templates from the local flake
#          using an interactive fzf interface.
#
# Not in nixpkgs: Personal workflow tool for template management.
#
# Usage: nix-template-selector   (run from the directory to scaffold into)
# Prerequisites: fzf, git, jq, nix installed (provided via runtimeInputs).
#
# Root resolution order (first match wins):
#   1. $TEMPLATE_FLAKE_ROOT   — explicit escape hatch
#   2. $HOME/nixos-config, $HOME/.config/nixos, /etc/nixos
#   3. Walk up from $PWD, accepting a directory only if it has BOTH a
#      flake.nix AND a sibling templates/ directory.
#      Step 3 is a filesystem test, not a flake.nix content grep: a project
#      scaffolded *from* one of these templates also carries a flake.nix that
#      mentions flake-parts/nixos-unified, so a content grep latches onto the
#      wrong flake and then hard-fails because it has no templates output.
# =============================================================================

{ writeShellApplication, nix, fzf, git, jq }:
writeShellApplication {
  name = "nix-template-selector";
  meta = {
    description = "Interactive Nix flake template selector using fzf";
    longDescription = ''
      Lists available templates from the local NixOS configuration flake
      and presents an interactive fzf menu to select and initialize a template
      in the current directory.

      Usage: nix-template-selector

      The tool will:
      1. Locate the nixos-config flake (see root resolution order above)
      2. List available templates from its `templates` output
      3. Show an interactive fzf selector
      4. Initialize the selected template with `nix flake init`

      Set TEMPLATE_FLAKE_ROOT to override flake discovery.
    '';
    license = "MIT";
    mainProgram = "nix-template-selector";
  };
  runtimeInputs = [
    nix
    fzf
    git
    jq
  ];
  text = ''
    set -euo pipefail

    # A directory is the nixos-config flake if it has a flake.nix AND a
    # templates/ directory beside it. Cheap, and unambiguous.
    is_flake_root() {
      [[ -f "$1/flake.nix" && -d "$1/templates" ]]
    }

    find_flake_root() {
      # 1. Explicit override
      if [[ -n "''${TEMPLATE_FLAKE_ROOT:-}" ]]; then
        echo "''${TEMPLATE_FLAKE_ROOT/#\~/$HOME}"
        return 0
      fi

      # 2. Well-known locations
      local candidate
      for candidate in "$HOME/nixos-config" "$HOME/.config/nixos" "/etc/nixos"; do
        if is_flake_root "$candidate"; then
          echo "$candidate"
          return 0
        fi
      done

      # 3. Walk up from the current directory. Skips scaffolded template
      #    projects, which have a flake.nix but no templates/ sibling.
      candidate="$PWD"
      while [[ "$candidate" != "/" ]]; do
        if is_flake_root "$candidate"; then
          echo "$candidate"
          return 0
        fi
        candidate="$(dirname "$candidate")"
      done

      return 1
    }

    FLAKE_ROOT=$(find_flake_root) || FLAKE_ROOT=""

    if [[ -z "$FLAKE_ROOT" ]]; then
      echo "Could not locate the nixos-config flake."
      echo "Looked in: \$TEMPLATE_FLAKE_ROOT, ~/nixos-config, ~/.config/nixos,"
      echo "           /etc/nixos, and every parent of \$PWD."
      read -rp "Enter path to your nixos-config flake: " FLAKE_ROOT
      FLAKE_ROOT="''${FLAKE_ROOT/#\~/$HOME}"
      if [[ ! -f "$FLAKE_ROOT/flake.nix" ]]; then
        echo "Error: No flake.nix found at $FLAKE_ROOT"
        exit 1
      fi
    fi

    echo "Using flake at: $FLAKE_ROOT"

    # Load templates — use nix eval (fast: only evaluates templates attr, not whole flake)
    echo "Loading templates..."
    TEMPLATES_JSON=$(nix eval "$FLAKE_ROOT#templates" --json 2>/dev/null || true)

    if [[ -z "$TEMPLATES_JSON" ]] || [[ "$TEMPLATES_JSON" == "{}" ]]; then
      echo "Error: no templates found at $FLAKE_ROOT#templates"
      exit 1
    fi

    TEMPLATE_LIST=$(echo "$TEMPLATES_JSON" | jq -r 'to_entries[] | "\(.key) - \(.value.description // "No description")"') || true

    if [[ -z "$TEMPLATE_LIST" ]]; then
      echo "Error: Could not parse templates"
      exit 1
    fi

    # Use fzf to select and initialize
    SELECTED_LINE=$(echo "$TEMPLATE_LIST" | fzf --prompt="Select a template: " --height=40% --border) || true

    if [[ -z "$SELECTED_LINE" ]]; then
      echo "No template selected"
      exit 1
    fi

    SELECTED="''${SELECTED_LINE%% - *}"

    echo "Initializing template: $SELECTED"
    nix flake init --template "$FLAKE_ROOT#$SELECTED"

    echo "✓ Template '$SELECTED' initialized successfully!"
  '';
}