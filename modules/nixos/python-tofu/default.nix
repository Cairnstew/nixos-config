# modules/nixos/python-tofu/default.nix
# Import manifest only — see modules/AGENT.md.
#
# THIN WRAPPER around the upstream flake input github:Cairnstew/python-tofu
# (pinned in flake.lock). The upstream module owns the whole option surface
# under `services.python-tofu.*` (the systemd oneshot, argv routing, the
# build-time stack evaluation, sandboxing and restartTriggers); this module
# deliberately does not re-export it under `my.*`.
#
# What stays local is what is about THIS config rather than about python-tofu:
#   - `my.services.python-tofu.enable` — the repo's opt-in switch
#   - `stack`/`stackFile` passthrough for Nix-authored stacks
#   - the agenix `gcloud-auth` credential wiring (AGENTS.md §6.4 guard)
#   - `applyOnRebuild` convenience for reconcile-on-switch
{ flake, ... }:
{
  imports = [
    # Import through `nixosModules`, not the bare `nix/module.nix` path: the
    # output fills `services.python-tofu.package` with mkDefault from the
    # flake's own per-system packages.
    flake.inputs.python-tofu.nixosModules.default

    ./options.nix
    ./config.nix

    # Repo-specific assertions.
    ./tests.nix
  ];
}
