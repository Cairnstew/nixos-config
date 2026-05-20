# =============================================================================
# git-merge-and-delete.nix — Git Branch Cleanup Helper
# =============================================================================
# Purpose: Automates the workflow of merging a feature branch to main,
#          pushing, and cleaning up local and remote branches.
#
# Not in nixpkgs: Personal workflow automation script.
#
# Usage: git-merge-and-delete <branch-name>
# Prerequisites: Must be on the branch to merge, branch must be clean.
# =============================================================================

{ writeShellApplication, git, ... }:

writeShellApplication {
  name = "git-merge-and-delete";
  meta = {
    description = "Merge a branch to main, push, and clean up branches";
    longDescription = ''
      Automates the common git workflow:
      1. Verifies you're on the correct branch
      2. Checks for uncommitted changes
      3. Switches to main and merges the branch
      4. Pushes main to origin
      5. Deletes the feature branch locally and remotely
      
      Usage: git-merge-and-delete <branch-name>
    '';
    homepage = "https://git-scm.com/";
    license = "MIT";
    mainProgram = "git-merge-and-delete";
  };
  runtimeInputs = [ git ];
  text = ''
    # Set some fancy colors
    RED='\033[0;31m'
    # GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color

    # Function to print colorful messages
    print_message() {
        >&2 echo -e ''${YELLOW}🚀 $1''${NC}
    }

    # Function to print and execute git commands
    git_command() {
        >&2 echo -e ''${BLUE}> git $*''${NC}
        git "$@"
    }

    # Check if branch name is provided
    if [ $# -eq 0 ]; then
        echo -e ''${RED}❌ Error: No branch name provided. Usage: $0 <branch_name>''${NC}
        exit 1
    fi

    BRANCH_NAME=$1

    # Check if we're on the correct branch
    current_branch=$(git_command rev-parse --abbrev-ref HEAD)
    if [ "$current_branch" != "$BRANCH_NAME" ]; then
        echo -e ''${RED}❌ Oops! You're not on the '$BRANCH_NAME' branch. Aborting mission!''${NC}
        exit 1
    fi

    # Check for dirty changes
    if ! git_command diff-index --quiet HEAD --; then
        echo -e ''${RED}❌ Houston, we have a problem! There are uncommitted changes. Commit or stash them first.''${NC}
        exit 1
    fi

    print_message "All systems go! Preparing for merge..."

    # Switch to main branch
    git_command checkout main

    # Merge the specified branch into main
    if git_command merge "$BRANCH_NAME"; then
        print_message "Merge successful! Ready for liftoff..."
    else
        echo -e ''${RED}❌ Merge conflict detected! Abort! Abort!''${NC}
        exit 1
    fi

    # Push changes to remote
    print_message "Pushing changes to the mothership..."
    git_command push origin main

    # Delete the specified branch locally and remotely
    print_message "Time to clean up our space debris..."
    git_command branch -d "$BRANCH_NAME"
    git_command push origin --delete "$BRANCH_NAME"

    # Run git status
    print_message "And now, the final systems check..."
    git_command status

    print_message "Mission accomplished! You're clear for your next adventure, Space Cowboy! 🌠"
  '';
}
