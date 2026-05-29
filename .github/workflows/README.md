# GitHub Workflows

This directory contains GitHub Actions workflows for the NixOS configuration repository.

## Workflow Architecture

The CI system uses a **path-aware** strategy:

- **PRs**: Smart CI runs only the checks relevant to changed files
- **Push to main**: Smart CI runs all lightweight checks + builds + tests
- **Scheduled**: Full CI runs all builds to catch upstream breakage

### Smart CI (`smart-ci.yml`)
**Triggers:** PR to main, push to main, manual dispatch

Path-aware CI that **only runs checks relevant to changed files**:

| Path Changed | Jobs Triggered |
|---|---|
| `flake.nix`, `flake.lock`, `config.nix` | Flake check, eval all hosts, build packages |
| `modules/flake-parts/**` | Flake check, eval all hosts |
| `modules/nixos/**` | Eval all NixOS hosts, run tests |
| `modules/home/**` | Eval home configurations |
| `configurations/nixos/laptop/**` | Eval **only** the laptop host |
| `configurations/nixos/server/**` | Eval **only** the server host |
| `configurations/nixos/wsl/**` | Eval **only** the WSL host |
| `configurations/nixos/desktop/**` | Eval **only** the desktop host |
| `configurations/nixos/minimal/**` | Eval **only** the minimal host |
| `packages/**` | Build affected packages + Cachix push |
| `overlays/**` | Eval all hosts (overlays affect everything) |
| `templates/**` | Validate each template flake |
| `secrets/**` | Validate secrets catalog structure |
| `scripts/**` | Shellcheck scripts |
| `.github/workflows/**` | Flake check |
| `**/*.nix` | Format check |
| **Push to main (any)** | All of the above + test suite |

On PRs, only lightweight `nix eval` runs. On push to main, full builds + Cachix caching + test suite execute.

### Format Check (`format-check.yml`)
**Triggers:** Push to main, PR to main (only when `**/*.nix` changes)

Verifies code formatting using `nix fmt` with nixpkgs-fmt. Only triggers when `.nix` files are modified.

### Full CI (`ci.yml`)
**Triggers:** Daily cron, manual dispatch

Heavyweight CI for comprehensive validation:
- Builds each host, pushes results to Cachix
- Runs test suite via `nix run .#test`
- Performs `nix flake check`
- Builds dev shells

### PR Checks (`pr-checks.yml`)
**Triggers:** PR opened, synchronized, reopened

Fast PR validation:
- Quick eval of each host
- Lint checks (secrets, TODO/FIXME detection)
- **PR summary comment** with impact analysis:
  - Categorized changed files
  - Affected hosts list
  - Stale `flake.lock` warning (nixpkgs >7 days)

### Module Lint (`module-lint.yml`)
**Triggers:** Push/PR to main when `modules/nixos/**` or `modules/home/**` change

Validates module structure:
- Verifies `default.nix` files are import-only (no logic)
- Checks multi-file modules have `meta.nix`
- Warns about `options.nix`/`config.nix` asymmetry
- Runs `nix flake check --no-build`

### Package Check (`package-check.yml`)
**Triggers:** Push/PR to main when `packages/**` change

Builds flake apps/packages and pushes to Cachix.

### Template Validate (`template-validate.yml`)
**Triggers:** Push/PR to main when `templates/**` change

Validates every template's `flake.nix` evaluates via `nix flake check --no-build`.

### Build & Cache (`build-cache.yml`)
**Triggers:** Daily cron, manual dispatch

Keeps the Cachix cache warm by building all configurations and packages on a schedule.

### Update Flake Inputs (`update-flake.yml`)
**Triggers:** Weekly cron (Sundays), manual dispatch

Automatically updates flake inputs and creates a PR with the changes:
- Runs `nix run .#update` to update primary inputs
- Creates a pull request for review
- Supports selective input updates via workflow dispatch

### Release NixOS ISO/WSL (`release-nixos-iso.yml`)
**Triggers:** Manual dispatch

Builds and releases ISO/WSL images:
- Supports laptop, server, and wsl hosts
- Creates rolling releases (overwrites previous)
- Splits large files into chunks for GitHub releases
- Provides join scripts for reassembly
- Includes SHA-256 checksums

### Health Check (`health-check.yml`)
**Triggers:** Daily cron, manual dispatch

Monitors flake health:
- Verifies all configurations evaluate without errors
- Checks for outdated inputs
- Creates GitHub issues when updates are available

### Cleanup Cachix (`cleanup-cachix.yml`)
**Triggers:** Monthly, manual dispatch

Provides information about Cachix cache maintenance.

### VM Tests (`vm-tests.yml`)
**Triggers:** Manual dispatch only

Runs the NixOS VM integration tests (QEMU-based):
- Requires `/dev/kvm` — **not available on GitHub Actions shared runners**
- Intended for self-hosted runners or local execution

### Local Verification (`local-verify.yml`)
**Triggers:** Push to non-main branches, manual dispatch

Lightweight checks designed to run locally with [`act`](https://github.com/nektos/act):
- Configuration evaluation (no builds)
- Format checking
- Static analysis/linting
- Flake check (--no-build)

No secrets or Cachix auth required!

## External Action Dependencies

| Action | Usage |
|--------|-------|
| [`dorny/paths-filter`](https://github.com/dorny/paths-filter) v3 | Path change detection (smart-ci.yml) |
| [`actions/checkout`](https://github.com/actions/checkout) v6 | Repository checkout |
| [`cachix/install-nix-action`](https://github.com/cachix/install-nix-action) v31 | Nix installation |
| [`cachix/cachix-action`](https://github.com/cachix/cachix-action) v17 | Cachix cache push/setup |
| [`actions/github-script`](https://github.com/actions/github-script) v7 | GitHub API interactions |

## Required Secrets

| Secret | Description |
|--------|-------------|
| `CACHIX_AUTH_TOKEN` | Authentication token for Cachix cache push access |
| `GITHUB_TOKEN` | Automatically provided, used for releases and PR creation |

## Cachix Cache

**Cache Name:** `cairnstew-nixos-config-cache`

The cache is configured in:
- `flake.nix` - Binary cache substituters
- All workflows - For pushing build results

## Path-Filtering Strategy

The `smart-ci.yml` workflow uses [`dorny/paths-filter`](https://github.com/dorny/paths-filter) to detect which
paths changed in a PR/push. Each job checks the filter outputs alongside the event type to decide whether to run:

```yaml
if: |
  needs.changes.outputs.laptop == 'true' ||
  needs.changes.outputs.nixos-modules == 'true' ||
  needs.changes.outputs.flake-core == 'true' ||
  needs.changes.outputs.overlays == 'true' ||
  github.event_name == 'push' ||
  github.event_name == 'schedule'
```

**Rules of thumb for adding new filters:**
1. Add the path glob to the `changes` job's filter map
2. Create a new job that gates on the new output
3. For host-specific checks, also gate on `nixos-modules`, `flake-core`, and `overlays`
4. Always include `github.event_name == 'push'` for full runs on main

## Adding a New Workflow

1. Create a new `.yml` file in `.github/workflows/`
2. Follow the existing patterns for Nix installation and Cachix setup
3. Use `paths` filter on the trigger to only run when relevant files change
4. Use the matrix strategy for multi-host builds
5. Include proper concurrency settings to cancel stale runs
6. If it makes sense as a path-aware check, add it to `smart-ci.yml` instead

## Manual Triggers

Most workflows support `workflow_dispatch` for manual runs:

```bash
# Via GitHub CLI
gh workflow run <workflow-name>

# Via web interface
# Actions > Workflows > [Select Workflow] > Run workflow
```

## Local Testing with `act`

The `local-verify.yml` workflow is optimized for [act](https://github.com/nektos/act) - run GitHub Actions locally!

### Quick Start (via Nix)

```bash
# Run all local checks
nix run .#act-verify

# Run specific checks
nix run .#act-verify -- eval-check    # Just evaluation
nix run .#act-verify -- format-check  # Just formatting
nix run .#act-verify -- lint-nix     # Just linting
nix run .#act-verify -- flake-check  # Just flake check

# List all available jobs
nix run .#act -- --list -W .github/workflows/local-verify.yml
```

### Quick Start (via Just)

```bash
# Run all local checks
just act

# Run specific checks
just act eval-check
just act format-check
just act lint-nix
just act flake-check

# List available jobs
just act-list
```

### Quick Start (raw act)

```bash
# Run all local checks
act -j verify-local -W .github/workflows/local-verify.yml

# Run specific checks
act -j eval-check    # Just evaluation
act -j format-check  # Just formatting
act -j lint-nix      # Just linting
act -j flake-check   # Just flake check
```

### Using the Local Verify App (No act needed)

```bash
# Run all checks
nix run .#local-verify

# Run specific checks
nix run .#local-verify -- eval
nix run .#local-verify -- fmt
nix run .#local-verify -- lint
nix run .#local-verify -- flake
```

### Why Local Verification?

- **Fast**: No ISO builds, just evaluation and static checks
- **No secrets**: Works without Cachix auth tokens
- **CI-like**: Same checks that run in CI, but locally
- **Pre-push**: Catch issues before pushing to GitHub
