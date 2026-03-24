{ lib, config, ... }:
{
  options.my.build.createImage = lib.mkOption {
    type = lib.types.package;
    default = 
      # Special case for WSL (your explicit requirement)
      if config.networking.hostName == "wsl" && (config.system.build ? tarballBuilder) then
        config.system.build.tarballBuilder

      # Default for normal NixOS hosts (you can change this)
      else if (config.system.build ? images && config.system.build.images ? iso) then
        config.system.build.images.iso
      else if config.system.build ? isoImage then
        config.system.build.isoImage
      else
        # Fallback / error
        throw "Host ${config.networking.hostName} has no default image builder. Please set my.build.createImage explicitly.";

    description = ''
      The image/tarball/ISO/VM derivation exposed as #<hostname>-create-image.
      - wsl   → tarballBuilder (explicit)
      - others → images.iso or isoImage (change the logic if you prefer a different default)
    '';
  };

  # Optional: also put it under the normal system.build namespace
  config.system.build.createImage = config.my.build.createImage;
}