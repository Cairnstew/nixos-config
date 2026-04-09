# terraform/default.nix
{ ... }: {
  imports = [
    ./providers.nix
    ./resources/servers.nix
    ./resources/dns.nix
    ./outputs.nix
  ];
}