{ config, lib, flake, ... }:
let
  inherit (lib) mkIf mkMerge;

  cfg = config.my.secrets;

  # Import the catalog
  catalog = (import ./catalog.nix { inherit flake lib; }).secretsCatalog;

  # Filter to only enabled secrets (those with non-null files)
  enabledSecrets = lib.filterAttrs (n: v: v.file != null) catalog;

  # Build a single age.secrets entry from catalog definition
  mkSecretEntry = path: secretDef: {
    age.secrets.${secretDef.name} = {
      file = lib.mkDefault secretDef.file;
      owner = lib.mkDefault secretDef.owner;
      group = lib.mkDefault secretDef.group;
      mode = lib.mkDefault secretDef.mode;
    };
  };

in
{
  config = mkIf cfg.enable (mkMerge [
    # Declare all enabled secrets from the catalog
    (mkMerge (lib.mapAttrsToList mkSecretEntry enabledSecrets))
  ]);
}
