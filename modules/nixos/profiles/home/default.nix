# modules/nixos/profiles/home/default.nix
# Home-level profiles that configure user programs
{ ... }:
{
  # Pure import manifest: option declarations and enable-logic live in
  # options.nix and config.nix respectively (F5). No logic here.
  imports = [
    ./options.nix
    ./config.nix
  ];
}
