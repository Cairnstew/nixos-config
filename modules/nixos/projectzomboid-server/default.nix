# modules/nixos/projectzomboid-server/default.nix
# Import manifest only — see modules/AGENT.md.
#
# This module is a THIN WRAPPER around the upstream flake input
# github:Cairnstew/nixos-projectzomboid-servers (pinned in flake.lock).
# Everything substantive lives upstream: the systemd units, the shared SteamCMD
# install, the .ini / SandboxVars.lua renderers, the console backends, the ttyd
# web console, map derivation, and the modpack catalogue.
#
# Options are therefore under the UPSTREAM namespace
# `services.project-zomboid-servers.*` — not `my.*`. See meta.nix's `provides`
# and README.md. The namespace change is deliberate upstream behaviour, not an
# oversight; see AGENTS.md §5.1 for why a wrapper is the correct seam.
{ flake, ... }:
{
  imports = [
    # Import through the flake's nixosModules, NOT the bare
    # modules/project-zomboid-servers.nix file: the wrapper around it is what
    # supplies `package` with mkDefault, and the module asserts `package` is
    # non-null. A flake input's module scope has no path back to its own flake,
    # so nothing else can fill it in.
    flake.inputs.project-zomboid-servers.nixosModules.project-zomboid-servers

    # Host-local wiring: dataDir, group membership, reverse-proxy upstreams.
    ./config.nix

    # Repo-specific assertions + smoke test.
    ./tests.nix

    # This repo's server catalog. The modpack catalogue is NOT here — it is
    # plain data exported as `self.modpacks` by the upstream flake and wired in
    # by servers/<name>.nix via `flake.inputs.project-zomboid-servers.modpacks`.
    ./servers
  ];
}
