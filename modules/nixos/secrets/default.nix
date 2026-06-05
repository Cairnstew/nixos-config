{ lib, flake, config, ... }: {
  imports = [
    flake.inputs.agenix.nixosModules.default
    ./tests.nix
  ];

  options.my.secrets.enable = lib.mkEnableOption "agenix-managed secrets" // {
    description = "Enable agenix secrets management. Delegates to agenixManager.enable at the system level.";
  };
}
