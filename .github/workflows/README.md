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
