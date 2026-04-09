# terraform/default.nix
{ ... }:

{
  imports = [
    ./providers.nix
    ./variables.nix
    ./vpc.nix
    ./ec2.nix
    ./outputs.nix
  ];
}
