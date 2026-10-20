# modules/nixos/sillytavern/default.nix
# Import manifest only — see modules/AGENT.md.
#
# This module is a THIN WRAPPER around the upstream flake input
# github:Cairnstew/SillyTavern (pinned in flake.lock). Everything substantive
# lives upstream: the systemd unit, the config.yaml renderer, the account
# seeder, the JSON state seeding (settings.json, presets, themes, world books),
# the pinned extension / server-plugin installs, the reverse-proxy hints and
# the assertions.
#
# Options are therefore under the UPSTREAM namespace
# `services.sillytavern-nixos.*` — not `my.*`.
#
# The namespace is NOT `services.sillytavern`: that one belongs to nixpkgs' own
# module (nixos/modules/services/web-apps/sillytavern.nix), which this config
# does not enable. Upstream asserts that the two are never both enabled,
# because they fight over the systemd unit, the system account and the state
# directory — none of which are namespaced by option path.
{ flake, ... }:
{
  imports = [
    # Import through the flake's nixosModules, NOT the bare
    # modules/sillytavern.nix file: the module supplies its own `package` with
    # mkDefault, and a flake input's module scope has no path back to its own
    # flake, so nothing else can fill it in.
    flake.inputs.sillytavern.nixosModules.sillytavern

    # Host-local wiring: reverse-proxy upstream, proxy trust, Ollama model pull.
    ./config.nix

    # Repo-specific assertions.
    ./tests.nix
  ];
}
