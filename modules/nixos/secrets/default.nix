# Import manifest for the secrets module.
#
# G3: `options.my.secrets.enable` was moved to ./options.nix so that this file
# is a pure import manifest (see modules/AGENT.md). Behavior is identical — the
# option is declared by ./options.nix, which is imported below.
{ flake, ... }:
{
  imports = [
    ./options.nix
    ./tests.nix
    flake.inputs.agenix.nixosModules.default
  ];
}
