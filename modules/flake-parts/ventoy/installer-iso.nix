{ config, lib, inputs, ... }:
let
  vCfg = config.ventoy;
  cfg = vCfg.installerIso;

  tsKeyPath = "/ts.key";          # path inside ISO image (isoImage.contents target)
  tsKeyRuntimePath = "/iso/ts.key"; # path at runtime in the booted live environment
  hasTsKey = cfg.tailscale.enable && cfg.tailscale.authKeyFile != null;
  tsKeyContent = if hasTsKey then builtins.readFile cfg.tailscale.authKeyFile else null;
in
{
  config.perSystem = { pkgs, system, ... }:
    let
      iso = (inputs.nixpkgs.lib.nixosSystem {
        system = cfg.system;
        modules = [
          "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          {
            boot.kernelParams = [ "console=tty1" "copytoram" ];
            boot.initrd.systemd.enable = lib.mkForce false;
            isoImage.squashfsCompression = "gzip -Xcompression-level 1";
            services.openssh = {
              enable = true;
              settings.PermitRootLogin = "yes";
            };
            users.users.root.openssh.authorizedKeys.keys = cfg.sshKeys;
            environment.systemPackages = cfg.extraPackages;
            nix.settings.experimental-features = [ "nix-command" "flakes" ];

            services.tailscale = lib.mkIf cfg.tailscale.enable {
              enable = true;
              openFirewall = true;
              authKeyFile = if hasTsKey then tsKeyRuntimePath else null;
              extraUpFlags = [ "--ssh" "--accept-routes" ];
            };

            systemd.services.tailscale-autoconnect = lib.mkIf (cfg.tailscale.enable && hasTsKey) {
              description = "Automatically connect Tailscale";
              after = [ "network-online.target" "tailscale.service" ];
              wants = [ "network-online.target" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig.Type = "oneshot";
              script = ''
                sleep 2
                ${pkgs.tailscale}/bin/tailscale up --authkey=$(cat ${tsKeyRuntimePath}) --ssh --accept-routes
              '';
            };
            isoImage.contents = lib.mkIf hasTsKey [
              {
                source = pkgs.writeText "ts.key" tsKeyContent;
                target = tsKeyPath;
              }
            ];
          }
        ];
      }).config.system.build.isoImage;
    in
    lib.optionalAttrs (system == cfg.system) {
      packages.ventoy-installer-iso = iso;
    };
}
