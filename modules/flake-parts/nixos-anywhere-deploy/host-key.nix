{ config, lib, ... }:
let
  cfg = config.my.nixosAnywhereDeploy;
  hostOptions = cfg.hosts or { };

  allHostNames = builtins.attrNames (config.flake.nixosConfigurations or { });

  enabledHosts = builtins.filter (name:
    if builtins.hasAttr name hostOptions then
      hostOptions.${name}.enable or true
    else
      true
  ) allHostNames;
in
{
  perSystem = { pkgs, ... }:
    let
      isLinux = builtins.elem pkgs.system [ "x86_64-linux" "aarch64-linux" ];

      prepPkgs = if isLinux then
        builtins.listToAttrs (map (hostName:
          lib.nameValuePair "prepare-keys-${hostName}" (pkgs.writeShellApplication {
            name = "prepare-keys-${hostName}";
            runtimeInputs = [ pkgs.openssh ];
            text = ''
              set -euo pipefail

              force=0
              for arg in "$@"; do
                if [ "$arg" = "--force" ]; then
                  force=1
                fi
              done

              keyDir="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")/.deploy-keys/${hostName}"

              if [ -d "$keyDir" ] && [ "$force" -eq 0 ]; then
                echo "Error: $keyDir already exists." >&2
                echo "Use --force to overwrite (this will invalidate any existing agenix rekey)." >&2
                exit 1
              fi

              mkdir -p "$keyDir/extra-files/etc/ssh"
              ssh-keygen -t ed25519 -f "$keyDir/ssh_host_ed25519_key" -N "" -q

              cp "$keyDir/ssh_host_ed25519_key" "$keyDir/extra-files/etc/ssh/ssh_host_ed25519_key"
              cp "$keyDir/ssh_host_ed25519_key.pub" "$keyDir/extra-files/etc/ssh/ssh_host_ed25519_key.pub"

              echo ""
              echo "Host key generated for ${hostName}:"
              cat "$keyDir/ssh_host_ed25519_key.pub"
              echo ""
              echo "Add the above public key to your agenix-manager config, then run:"
              echo "  agenix-manager rekey"
              echo ""
            '';
          })
        ) enabledHosts)
      else { };
    in
    {
      packages = prepPkgs;
    };
}
