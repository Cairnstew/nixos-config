# terraform/variables.nix
{ ... }:

{
  variable = {
    aws_region = {
      type        = "string";
      default     = "eu-west-2"; # London
      description = "AWS region to deploy into";
    };

    instance_type = {
      type        = "string";
      default     = "t3.micro";
      description = "EC2 instance type";
    };

    ami_id = {
      type        = "string";
      # Latest NixOS 24.11 x86_64 in eu-west-2 — update as needed
      # https://nixos.org/download/#nixos-amazon
      default     = "ami-0b6e5c5c5c5c5c5c5";
      description = "AMI to use for the EC2 instance";
    };

    key_name = {
      type        = "string";
      default     = "";
      description = "Name of an existing EC2 key pair for SSH access (leave empty for no key)";
    };
  };
}
