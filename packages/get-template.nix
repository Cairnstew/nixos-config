{ writeShellApplication, nix, fzf, git, jq }:
writeShellApplication {
  name = "nix-template-selector";
  runtimeInputs = [
    nix
    fzf
    git
    jq
  ];
  text = ''
    set -euo pipefail
    
    # Hardcoded repository URL
    REPO_URL="https://github.com/Cairnstew/my-flake-templates.git"
    TEMP_DIR=$(mktemp -d)
    
    # Cleanup on exit
    trap 'rm -rf "$TEMP_DIR"' EXIT
    
    echo "Fetching repository from $REPO_URL..."
    git clone --depth 1 "$REPO_URL" "$TEMP_DIR" 2>/dev/null
    
    cd "$TEMP_DIR"
    
    # Check if flake.nix exists
    if [ ! -f "flake.nix" ]; then
      echo "Error: No flake.nix found in repository"
      exit 1
    fi
    
    # Extract template names from flake
    echo "Loading templates..."
    
    # Redirect stderr to suppress progress messages, only capture stdout
    TEMPLATES=$(nix flake show --json 2>/dev/null | jq -r '.templates | keys[]' 2>/dev/null || true)
    
    if [ -z "$TEMPLATES" ]; then
      echo "Error: No templates found in flake"
      echo "Trying to show flake structure..."
      nix flake show
      exit 1
    fi
    
    # Use fzf to select template
    SELECTED=$(echo "$TEMPLATES" | fzf --prompt="Select a template: " --height=40% --border)
    
    if [ -z "$SELECTED" ]; then
      echo "No template selected"
      exit 1
    fi
    
    # Go back to original directory
    cd - > /dev/null
    
    # Initialize with selected template
    echo "Initializing template: $SELECTED"
    nix flake init --template "git+file://$TEMP_DIR#$SELECTED"
    
    echo "✓ Template '$SELECTED' initialized successfully!"
  '';
}