{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;

  # Secret definition type
  secretType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "The agenix secret name (used for age.secrets.<name>).";
      };

      fileRel = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Relative path from repo root to the .age file (e.g., \"/secrets/ai/token.age\"). Used for auto-generation.";
      };

      file = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to the encrypted .age file. If null, the secret must be declared elsewhere.";
      };

      owner = mkOption {
        type = types.str;
        default = "root";
        description = "File owner for the decrypted secret.";
      };

      group = mkOption {
        type = types.str;
        default = "root";
        description = "File group for the decrypted secret.";
      };

      mode = mkOption {
        type = types.str;
        default = "0400";
        description = "File permissions for the decrypted secret.";
      };
    };
  };
in
{
  options.my.secrets = {
    enable = mkEnableOption "agenix-managed secrets" // {
      description = "Enable agenix secrets management. When enabled, secrets defined in the catalog are automatically declared as age.secrets.";
    };

    # Note: catalog is defined in secrets.nix, not here
  };
}
