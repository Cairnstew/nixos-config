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
    FLAKE_ROOT=""

    find_flake_root() {
      local dir="$PWD"
      while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/flake.nix" ]]; then
          if grep -q "NixOS.*config\|nixos-unified\|flake-parts" "$dir/flake.nix" 2>/dev/null; then
            echo "$dir"
            return 0
          fi
        fi
        dir="$(dirname "$dir")"
      done
      return 1
    }

    FLAKE_ROOT=$(find_flake_root) || true

    if [[ -z "$FLAKE_ROOT" ]]; then
      for path in "$HOME/nixos-config" "$HOME/.config/nixos" "/etc/nixos"; do
        if [[ -f "$path/flake.nix" ]]; then
          FLAKE_ROOT="$path"
          break
        fi
      done
    fi

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

    # Load templates — use nix eval (fast: only evaluates templates attr, not whole flake)
    echo "Loading templates..."
    TEMPLATES_JSON=$(nix eval "$FLAKE_ROOT#templates" --json 2>/dev/null || nix eval "$FLAKE_ROOT#templates" 2>/dev/null) || true

    if [[ -z "$TEMPLATES_JSON" ]] || [[ "$TEMPLATES_JSON" == "{}" ]]; then
      echo "Error: No templates found in flake"
      exit 1
    fi

    TEMPLATE_LIST=$(echo "$TEMPLATES_JSON" | jq -r 'to_entries[] | "\(.key) - \(.value.description // "No description")"') || true

    if [[ -z "$TEMPLATE_LIST" ]]; then
      echo "Error: Could not parse templates"
      exit 1
    fi

    # Use fzf to select and initialize
    SELECTED_LINE=$(echo "$TEMPLATE_LIST" | fzf --prompt="Select a template: " --height=40% --border)

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
