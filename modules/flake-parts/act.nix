# =============================================================================
# act.nix — Local GitHub Actions Runner Integration
# =============================================================================
# Purpose: Integrates `nektos/act` so workflows can be tested locally before
#          pushing to GitHub.  Exposes both the raw `act` binary and a
#          project-specific `act-verify` convenience wrapper.
#
# Usage:
#   nix run .#act -- -j verify-local -W .github/workflows/local-verify.yml
#   nix run .#act-verify                # runs local-verify workflow
#   nix run .#act-verify -- eval-check  # run specific job
#
# Also available in the default devShell (via direnv / nix develop).
# =============================================================================

{ ... }: {
  perSystem = { pkgs, ... }:
    let
      act-verify = pkgs.writeShellApplication {
        name = "act-verify";
        runtimeInputs = [ pkgs.act ];
        text = ''
          set -euo pipefail

          WORKFLOW=".github/workflows/local-verify.yml"
          DEFAULT_JOB="verify-local"

          show_help() {
            cat <<EOF
          act-verify — Run GitHub Actions workflows locally with act

          Usage: act-verify [JOB] [EXTRA_ACT_ARGS...]

          Jobs (from local-verify.yml):
            verify-local   Run all local checks (default)
            eval-check     Evaluate NixOS configurations only
            format-check   Check code formatting only
            lint-nix       Run static analysis only
            flake-check    Run nix flake check --no-build only

          Examples:
            act-verify                          # default: verify-local
            act-verify eval-check               # single job
            act-verify -- --dry-run             # pass extra args to act
            act-verify format-check -- --dry-run
          EOF
          }

          # Parse arguments
          JOB=''${1:-$DEFAULT_JOB}

          case "$JOB" in
            --help|-h)
              show_help
              exit 0
              ;;
            verify-local|eval-check|format-check|lint-nix|flake-check)
              shift || true
              echo "==> Running act for job: $JOB"
              echo "    Workflow: $WORKFLOW"
              echo ""
              exec act -j "$JOB" -W "$WORKFLOW" "$@"
              ;;
            --*)
              # If first arg is an act flag, use default job and pass everything through
              echo "==> Running act for job: $DEFAULT_JOB (with flags)"
              echo "    Workflow: $WORKFLOW"
              echo ""
              exec act -j "$DEFAULT_JOB" -W "$WORKFLOW" "$JOB" "$@"
              ;;
            *)
              echo "Unknown job: $JOB"
              show_help
              exit 1
              ;;
          esac
        '';
      };
    in
    {
      packages = {
        act = pkgs.act;
        act-verify = act-verify;
      };

      apps = {
        act = {
          type = "app";
          program = "${pkgs.act}/bin/act";
          meta.description = "Run GitHub Actions workflows locally with nektos/act";
        };
        act-verify = {
          type = "app";
          program = "${act-verify}/bin/act-verify";
          meta.description = "Run the local-verify GitHub Actions workflow via act";
        };
      };
    };
}
