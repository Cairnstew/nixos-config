# GitHub Workflows

This directory contains GitHub Actions workflows for the NixOS configuration repository.

## Workflows Overview

### CI Workflow (`ci.yml`)
**Triggers:** Push to main, PR to main, daily cron

Builds and tests all NixOS configurations:
- Builds each host (laptop, server, wsl)
- Pushes results to Cachix cache
- Runs test suite via `nix run .#test`
- Performs `nix flake check`
- Builds dev shells for supported systems

### Build & Cache (`build-cache.yml`)
**Triggers:** Daily cron, manual dispatch

Keeps the Cachix cache warm by building all configurations and packages on a schedule.

### Update Flake Inputs (`update-flake.yml`)
**Triggers:** Weekly cron (Sundays), manual dispatch

Automatically updates flake inputs and creates a PR with the changes:
- Runs `nix run .#update` to update primary inputs
- Creates a pull request for review
- Supports selective input updates via workflow dispatch

### Format Check (`format-check.yml`)
**Triggers:** Push to main, PR to main

Verifies code formatting using `nix fmt` with nixpkgs-fmt.

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

Provides information about Cachix cache maintenance. Note: Direct cache deletion requires manual action via the Cachix web interface.

### VM Tests (`vm-tests.yml`)
**Triggers:** Manual dispatch only

Runs the NixOS VM integration tests (QEMU-based):
- Requires `/dev/kvm` — **not available on GitHub Actions shared runners**
- Intended for self-hosted runners or local execution
- Select individual tests or run all via workflow dispatch inputs
- Used to validate disko partitions, DSC YAML generation, and ISO building

### Local Verification (`local-verify.yml`)
**Triggers:** Push to non-main branches, manual dispatch

Lightweight checks designed to run locally with [`act`](https://github.com/nektos/act):
- Configuration evaluation (no builds)
- Format checking
- Static analysis/linting
- Flake check (--no-build)

No secrets or Cachix auth required!

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

## Adding a New Workflow

1. Create a new `.yml` file in `.github/workflows/`
2. Follow the existing patterns for Nix installation and Cachix setup
3. Use the matrix strategy for multi-host builds
4. Include proper concurrency settings to cancel stale runs

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
