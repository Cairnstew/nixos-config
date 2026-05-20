# =============================================================================
# get-template.nix — Interactive Nix Template Selector
# =============================================================================
# Purpose: Lists and initializes project templates from the local flake
#          using an interactive fzf interface.
#
# Not in nixpkgs: Personal workflow tool for template management.
#
# Usage: nix-template-selector
# Prerequisites: fzf, git, jq installed (provided via runtimeInputs).
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
      1. Find the local flake (nixos-config)
      2. Parse available templates from flake.nix
      3. Show an interactive fzf selector
      4. Initialize the selected template with `nix flake init`
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

    # Find the local flake root
    # First check if we're in a git repo that might be the flake
    FLAKE_ROOT=""

    # Try to find flake root by looking for flake.nix
    find_flake_root() {
      local dir="$PWD"
      while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/flake.nix" ]]; then
          # Verify it's a nixos-config flake by checking description or structure
          if grep -q "NixOS.*config\|nixos-unified\|flake-parts" "$dir/flake.nix" 2>/dev/null; then
            echo "$dir"
            return 0
          fi
        fi
        dir="$(dirname "$dir")"
      done
      return 1
    }

    # Try to find flake root
    FLAKE_ROOT=$(find_flake_root) || true

    # If not found, check common locations
    if [[ -z "$FLAKE_ROOT" ]]; then
      for path in "$HOME/nixos-config" "$HOME/.config/nixos" "/etc/nixos"; do
        if [[ -f "$path/flake.nix" ]]; then
          FLAKE_ROOT="$path"
          break
        fi
      done
    fi

    # If still not found, ask user
    if [[ -z "$FLAKE_ROOT" ]]; then
      echo "Could not auto-detect the nixos-config flake root."
      read -rp "Enter path to your nixos-config flake: " FLAKE_ROOT
      FLAKE_ROOT="''${FLAKE_ROOT/#\~/$HOME}"
      if [[ ! -f "$FLAKE_ROOT/flake.nix" ]]; then
        echo "Error: No flake.nix found at $FLAKE_ROOT"
        exit 1
      fi
    fi

    echo "Using flake at: $FLAKE_ROOT"
    cd "$FLAKE_ROOT"

    # Extract template names and descriptions from flake
    echo "Loading templates..."

    # Get templates as JSON object with name and description
    TEMPLATES_JSON=$(nix flake show --json 2>/dev/null | jq -r '.templates // {}')

    if [[ "$TEMPLATES_JSON" == "{}" ]] || [[ -z "$TEMPLATES_JSON" ]]; then
      echo "Error: No templates found in flake"
      echo "Trying to show flake structure..."
      nix flake show
      exit 1
    fi

    # Format for fzf: "name - description"
    TEMPLATE_LIST=$(echo "$TEMPLATES_JSON" | jq -r 'to_entries[] | "\(.key) - \(.value.description // "No description")"')

    if [[ -z "$TEMPLATE_LIST" ]]; then
      echo "Error: Could not parse templates"
      exit 1
    fi

    # Use fzf to select template
    SELECTED_LINE=$(echo "$TEMPLATE_LIST" | fzf --prompt="Select a template: " --height=40% --border)

    if [[ -z "$SELECTED_LINE" ]]; then
      echo "No template selected"
      exit 1
    fi

    # Extract template name (everything before " - ")
    SELECTED="''${SELECTED_LINE%% - *}"

    # Go back to original directory
    cd - > /dev/null

    # Initialize with selected template
    echo "Initializing template: $SELECTED"
    nix flake init --template "$FLAKE_ROOT#$SELECTED"

    echo "✓ Template '$SELECTED' initialized successfully!"
    echo ""
    echo "Next steps:"
    echo "  cd $(basename "$SELECTED")  # if in a new directory"
    echo "  nix develop                  # enter dev shell"
  '';
}
