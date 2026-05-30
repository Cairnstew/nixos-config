{ lib, ... }:
{
  assertions = [
    {
      assertion = lib.versionAtLeast (lib.versions.majorMinor lib.version) "24.11";
      message = "nixos-anywhere requires NixOS >= 24.11";
    }
  ];
}
