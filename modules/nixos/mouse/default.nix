# Import manifest for the mouse module.
#
# The maccel NixOS module (`hardware.maccel` options) is imported here rather
# than in config.nix (F9d split) so that config.nix contains no `imports`.
# It is unconditional — identical to the pre-split behaviour — because the
# `hardware.maccel` options are only *enabled* via `my.hardware.mouse.enable`.
{ flake, ... }:
{
  imports = [
    ./options.nix
    ./config.nix
    ./tests.nix
    flake.inputs.maccel.nixosModules.default
  ];
}
