# netboot installer builder — minimal SSH-accessible NixOS netboot for nixos-anywhere
{ pkgs, system ? pkgs.stdenv.hostPlatform.system }:

let
  eval = import "${pkgs.path}/nixos/lib/eval-config.nix" {
    inherit system;
    modules = [
      "${pkgs.path}/nixos/modules/installer/netboot/netboot.nix"
      "${pkgs.path}/nixos/modules/installer/netboot/netboot-minimal.nix"
      {
        services.openssh.enable = true;
        users.users.root.password = "nixos123";
      }
    ];
  };
in
rec {
  inherit (eval.config.system.build) kernel netbootRamdisk;
}
