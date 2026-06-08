{ lib, ... }:
{
  assertions = [
    {
      assertion = lib.versionAtLeast (lib.versions.majorMinor lib.version) "24.11";
      message = "nixos-deploy-tool wraps nixos-anywhere, which requires NixOS >= 24.11";
    }
  ];
}
