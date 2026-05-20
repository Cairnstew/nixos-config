{ config, lib, flake, ... }:
let
  # Import the catalog
  catalog = (import ./catalog.nix { inherit flake lib; }).secretsCatalog;
in
{
  # Expose the catalog as a read-only option
  options.my.secrets.catalog = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = catalog;
    readOnly = true;
    description = ''
      Catalog of available secrets. Each entry maps a logical path to a secret
      definition containing name, file path, owner, group, and mode.
      Secrets are accessed via their agenix name in config.age.secrets.
    '';
  };
}
