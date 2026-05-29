{ config, inputs, lib, ... }: {
  perSystem = { pkgs, system, ... }:
    let
      isoDir = ../../packages/installer-iso;
      configurationModule = "${toString isoDir}/configuration.nix";
      secretsDir = "${toString isoDir}/secrets";
      hasSecrets = builtins.pathExists (toString secretsDir);
      secrets = name: default:
        if hasSecrets then builtins.readFile ("${secretsDir}/${name}") else default;
      rootAuthorizedKey = secrets "authorized_keys" "MISSING-SECRETS";
    in
    {
      packages.installer-iso = (inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          configurationModule
          {
            isoImage.contents = [
              {
                source = pkgs.writeText "ts.key" (secrets "ts.key" "MISSING-SECRETS-RUN-just-build-iso");
                target = "/iso/ts.key";
              }
              {
                source = pkgs.writeText "authorized_keys" (secrets "authorized_keys" "MISSING-SECRETS");
                target = "/iso/authorized_keys";
              }
              {
                source = pkgs.writeText "ssh_host_ed25519_key" (secrets "ssh_host_ed25519_key" "MISSING-SECRETS");
                target = "/iso/ssh_host_ed25519_key";
              }
              {
                source = pkgs.writeText "ssh_host_ed25519_key.pub" (secrets "ssh_host_ed25519_key.pub" "MISSING-SECRETS");
                target = "/iso/ssh_host_ed25519_key.pub";
              }
            ];
          }
        ];
        specialArgs = { inherit inputs rootAuthorizedKey; };
      }).config.system.build.isoImage;
    };
}
