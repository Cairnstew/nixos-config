{ inputs, self, lib, ... }:

let
  # Automatically derived from configurations/nixos/* by autoWire
  nixosHosts = builtins.attrNames self.nixosConfigurations;

  # Pin to a commit SHA for reproducibility
  # Update with: https://github.com/nix-community/terraform-nixos/commits/master
  terraformNixosRef = "ced68729b6a0382dda02401c8f663c9b29c29368";

  sharedVarsModule = { ... }: {
    variable."ssh_private_key" = {
      type      = "string";
      sensitive = true;
    };
  };

  mkDeployModule = hostname: { ... }: {
    variable."host_${hostname}" = {
      type        = "string";
      description = "IP or hostname for ${hostname}";
    };

    module."deploy_nixos_${hostname}" = {
      source               = "github.com/nix-community/terraform-nixos//deploy_nixos?ref=${terraformNixosRef}";
      nixos_config         = "${self}/configurations/nixos/${hostname}";
      target_host          = "\${var.host_${hostname}}";
      ssh_private_key_file = "\${var.ssh_private_key}";
      ssh_user             = "root";
    };
  };

in
{
  imports = [ inputs.terranix.flakeModules.default ];

  perSystem = { ... }: {
    terranix.terranixConfigurations =
      builtins.listToAttrs (map (hostname: {
        name  = hostname;
        value = {
          # Reuse the same directory autoWire already points at
          modules = [
            "${self}/configurations/nixos/${hostname}"
            sharedVarsModule
            (mkDeployModule hostname)
          ];

          # State is persistent across runs — one dir per host
          workdir = "\${XDG_STATE_HOME:-$HOME/.local/state}/terraform/${hostname}";
        };
      }) nixosHosts);
  };
}
