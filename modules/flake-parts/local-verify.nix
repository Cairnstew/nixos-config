# =============================================================================
# local-verify.nix — Local Verification Script
# =============================================================================
# Purpose: Provides a quick local verification command that runs lightweight
#          checks without needing CI or heavy builds.
#
# Usage:
#   nix run .#local-verify          # Run all checks
#   nix run .#local-verify -- eval  # Just evaluation
#   nix run .#local-verify -- fmt   # Just formatting
#   nix run .#local-verify -- lint  # Just linting
# =============================================================================

{ ... }: {
  perSystem = { pkgs, ... }:
    let
      local-verify-script = pkgs.writeShellApplication {
        name = "local-verify";
        runtimeInputs = with pkgs; [
          nix
          git
          nixpkgs-fmt
          gnugrep
          gawk
          coreutils
          findutils
        ];
        text = ''
          set -euo pipefail

          RED='\033[0;31m'
          GREEN='\033[0;32m'
          YELLOW='\033[1;33m'
          NC='\033[0m' # No Color

          usage() {
            cat <<EOF
          Local verification for NixOS configuration

          Usage: local-verify [COMMAND]

          Commands:
            all      Run all checks (default)
            eval     Evaluate all configurations
            fmt      Check code formatting
            lint     Run static analysis
            flake    Run nix flake check --no-build

          Options:
            --help, -h    Show this help

          Examples:
            nix run .#local-verify
            nix run .#local-verify -- eval
            nix run .#local-verify -- lint fmt
          EOF
          }

          check_eval() {
            echo ""
            echo "=========================================="
            echo "🔍 Checking NixOS configuration evaluation"
            echo "=========================================="
            
            local failed=0
            for host in laptop server wsl; do
              echo ""
              echo "→ Evaluating $host..."
              if nix eval ".#nixosConfigurations.$host.config.system.build.toplevel" --json > /dev/null 2>&1; then
                echo -e "  ''${GREEN}✓''${NC} $host evaluates successfully"
              else
                echo -e "  ''${RED}✗''${NC} $host evaluation failed"
                failed=1
              fi
            done
            
            echo ""
            if [ $failed -eq 0 ]; then
              echo -e "''${GREEN}✓ All configurations evaluate successfully''${NC}"
              return 0
            else
              echo -e "''${RED}✗ Some configurations failed to evaluate''${NC}"
              return 1
            fi
          }

          check_format() {
            echo ""
            echo "=========================================="
            echo "🎨 Checking code formatting"
            echo "=========================================="
            
            local failed=0
            local files_checked=0
            
            while IFS= read -r file; do
              files_checked=$((files_checked + 1))
              if ! ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check "$file" 2>/dev/null; then
                echo -e "  ''${RED}✗''${NC} $file"
                failed=1
              fi
            done < <(find . -name "*.nix" -not -path "./.git/*" -not -path "./result*" 2>/dev/null)
            
            echo ""
            if [ $failed -eq 0 ]; then
              echo -e "''${GREEN}✓ All $files_checked files are properly formatted''${NC}"
              return 0
            else
              echo -e "''${YELLOW}⚠ Some files need formatting''${NC}"
              echo "Run 'nix fmt' to fix formatting issues"
              return 1
            fi
          }

          check_lint() {
            echo ""
            echo "=========================================="
            echo "🧹 Running static analysis"
            echo "=========================================="
            
            local issues=0
            local secrets todos todo_count lines
            
            # Check for potential hardcoded secrets
            echo "→ Checking for potential secrets..."
            secrets=$(grep -r "password\s*=\s*\"" --include="*.nix" . 2>/dev/null | grep -v "example\|test\|dummy" || true)
            if [ -n "$secrets" ]; then
              echo -e "  ''${YELLOW}⚠ Found potential hardcoded password:''${NC}"
              echo "$secrets" | head -3
              issues=$((issues + 1))
            fi
            
            # Check for TODO/FIXME
            echo "→ Checking for TODO/FIXME comments..."
            todos=$(grep -r "TODO\|FIXME\|XXX" --include="*.nix" . 2>/dev/null || true)
            todo_count=$(echo "$todos" | grep -c . || echo 0)
            if [ "$todo_count" -gt 0 ]; then
              echo -e "  ''${YELLOW}ℹ Found $todo_count TODO/FIXME comment(s)''${NC}"
            fi
            
            # Check for empty files
            echo "→ Checking for empty/placeholder files..."
            while IFS= read -r file; do
              lines=$(grep -c . "$file" 2>/dev/null || echo 0)
              if [ "$lines" -lt 5 ]; then
                echo -e "  ''${YELLOW}ℹ $file has only $lines lines''${NC}"
              fi
            done < <(find . -name "*.nix" -not -path "./.git/*" 2>/dev/null)
            
            echo ""
            if [ $issues -eq 0 ]; then
              echo -e "''${GREEN}✓ No critical issues found''${NC}"
              return 0
            else
              echo -e "''${YELLOW}⚠ Found $issues potential issue(s)''${NC}"
              return 0  # Don't fail on lint warnings
            fi
          }

          check_flake() {
            echo ""
            echo "=========================================="
            echo "🔧 Running nix flake check --no-build"
            echo "=========================================="
            
            if nix flake check --no-build 2>&1; then
              echo ""
              echo -e "''${GREEN}✓ Flake check passed''${NC}"
              return 0
            else
              echo ""
              echo -e "''${RED}✗ Flake check failed''${NC}"
              return 1
            fi
          }

          # Main
          cmd=''${1:-all}
          
          case "$cmd" in
            --help|-h)
              usage
              exit 0
              ;;
            all)
              failed=0
              check_eval || failed=1
              check_flake || failed=1
              check_format || failed=1
              check_lint || true  # Don't fail on lint
              
              echo ""
              echo "=========================================="
              if [ $failed -eq 0 ]; then
                echo -e "''${GREEN}✅ All checks passed!''${NC}"
                exit 0
              else
                echo -e "''${RED}❌ Some checks failed''${NC}"
                exit 1
              fi
              ;;
            eval)
              check_eval
              ;;
            fmt|format)
              check_format
              ;;
            lint)
              check_lint
              ;;
            flake)
              check_flake
              ;;
            *)
              echo "Unknown command: $cmd"
              usage
              exit 1
              ;;
          esac
        '';
      };
    in
    {
      packages = {
        local-verify = local-verify-script;
      };
      apps = {
        local-verify = {
          type = "app";
          program = "${local-verify-script}/bin/local-verify";
          meta.description = "Run local verification checks (eval, fmt, lint, flake)";
        };
      };
    };
}
