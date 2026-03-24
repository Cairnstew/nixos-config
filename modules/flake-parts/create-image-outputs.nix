{ self, lib, ... }:
{
  # This runs after all nixosConfigurations are defined
  flake = {
    # Automatic packages: wsl-create-image, server-create-image, etc.
    packages = lib.mapAttrs' (hostName: cfg:
      lib.nameValuePair "${hostName}-create-image" cfg.config.my.build.createImage
    ) self.nixosConfigurations;

    # Automatic apps (makes `nix run .#wsl-create-image` work nicely)
    apps = lib.mapAttrs' (hostName: cfg:
      lib.nameValuePair "${hostName}-create-image" {
        type = "app";
        # Works great for tarballBuilder and most other builders
        program = "${cfg.config.my.build.createImage}/bin/*";
      }
    ) self.nixosConfigurations;
  };
}