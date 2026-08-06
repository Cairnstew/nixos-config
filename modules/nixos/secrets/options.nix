# Option declarations for the secrets module.
#
# G3: `options.my.secrets.enable` was moved here from default.nix so that
# default.nix is a pure import manifest. It is a vestigial option — no
# `config.my.secrets` consumer exists; agenix is enabled via
# `agenixManager.enable` at the system level.
{ lib, ... }:
{
  options.my.secrets.enable = lib.mkEnableOption "agenix-managed secrets" // {
    description = "Enable agenix secrets management. Delegates to agenixManager.enable at the system level.";
  };
}
