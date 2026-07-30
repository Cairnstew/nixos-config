{ config, lib, ... }:
let
  cfg = config.my.programs.hearthstone;
in
{
  assertions = [
    {
      assertion = true;
      message = "Placeholder — hearthstone-linux-gui flake input must be present in flake.nix.";
    }
  ];
}
