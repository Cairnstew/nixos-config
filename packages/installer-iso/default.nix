{ pkgs, system ? pkgs.stdenv.hostPlatform.system }:

let
  secretsDir = ./secrets;
  hasSecrets = builtins.pathExists secretsDir;

  readSecret = name: default:
    if hasSecrets then
      builtins.readFile (secretsDir + "/${name}")
    else
      default;

  isoEval = import "${pkgs.path}/nixos/lib/eval-config.nix" {
    inherit system;
    modules = [
      "${pkgs.path}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
      ./configuration.nix
      {
        isoImage.contents = [
          {
            source = pkgs.writeText "ts.key" (readSecret "ts.key" "MISSING-SECRETS-RUN-just-build-iso");
            target = "/iso/ts.key";
          }
          {
            source = pkgs.writeText "authorized_keys" (readSecret "authorized_keys" "MISSING-SECRETS");
            target = "/iso/authorized_keys";
          }
          {
            source = pkgs.writeText "ssh_host_ed25519_key" (readSecret "ssh_host_ed25519_key" "MISSING-SECRETS");
            target = "/iso/ssh_host_ed25519_key";
          }
          {
            source = pkgs.writeText "ssh_host_ed25519_key.pub" (readSecret "ssh_host_ed25519_key.pub" "MISSING-SECRETS");
            target = "/iso/ssh_host_ed25519_key.pub";
          }
        ];
      }
    ];
  };
in
isoEval.config.system.build.isoImage
