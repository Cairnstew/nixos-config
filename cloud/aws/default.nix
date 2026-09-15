# cloud/aws/default.nix — Amazon Web Services infrastructure (terranix module)
#
# Terranix module (not a NixOS module) evaluated into `config.tf.json` and
# driven by OpenTofu via the terranix flakeModule:
#
#   nix run .#aws -- plan
#   nix run .#aws -- apply
#   nix run .#aws -- destroy
#
# Two-stage pattern: this provisions the VPC + EC2 host, then the NixOS
# configuration is pushed with `nixos-anywhere` / `colmena`
# (see cloud/README.md).
{ lib, ... }:
{
  terraform.required_providers.aws = {
    source = "hashicorp/aws";
    version = "~> 5.0";
  };

  # ── Variables (supplied via TF_VAR_* by the wrapper) ──────────────────────
  variable.region = {
    description = "AWS region";
    type = "string";
    default = "eu-west-2";
  };

  variable.ssh_pub_key = {
    description = "SSH public key to import as the `nixos-cloud` key pair";
    type = "string";
  };

  # (instance_type variable removed — no EC2 instance provisioned)

  provider.aws = {
    region = lib.tf.ref "var.region";
  };

  # ── NixOS AMI ─────────────────────────────────────────────────────────────
  # Official NixOS AMIs are published under owner 520461471651.
  data.aws_ami.nixos = {
    most_recent = true;
    filter = [
      { name = "name"; values = [ "NixOS-*" ]; }
      { name = "architecture"; values = [ "x86_64" ]; }
      { name = "virtualization-type"; values = [ "hvm" ]; }
    ];
    owners = [ "520461471651" ];
  };

  # ── SSH key pair (from the agenix `aws-ssh-pub-key` secret) ───────────────
  resource.aws_key_pair.main = {
    key_name = "nixos-cloud";
    public_key = lib.tf.ref "var.ssh_pub_key";
  };

  # ── VPC ───────────────────────────────────────────────────────────────────
  resource.aws_vpc.main = {
    cidr_block = "10.1.0.0/16";
    enable_dns_hostnames = true;
    tags = { Name = "nixos-cloud"; };
  };

  resource.aws_internet_gateway.main = {
    vpc_id = lib.tf.ref "aws_vpc.main.id";
    tags = { Name = "nixos-cloud"; };
  };

  resource.aws_subnet.main = {
    vpc_id = lib.tf.ref "aws_vpc.main.id";
    cidr_block = "10.1.0.0/24";
    availability_zone = "${lib.tf.ref "var.region"}a";
    map_public_ip_on_launch = true;
    tags = { Name = "nixos-cloud"; };
  };

  resource.aws_route_table.main = {
    vpc_id = lib.tf.ref "aws_vpc.main.id";
    route = [{
      cidr_block = "0.0.0.0/0";
      gateway_id = lib.tf.ref "aws_internet_gateway.main.id";
    }];
    tags = { Name = "nixos-cloud"; };
  };

  resource.aws_route_table_association.main = {
    subnet_id = lib.tf.ref "aws_subnet.main.id";
    route_table_id = lib.tf.ref "aws_route_table.main.id";
  };

  # ── Security group ────────────────────────────────────────────────────────
  resource.aws_security_group.main = {
    name = "nixos-cloud";
    description = "NixOS cloud instance";
    vpc_id = lib.tf.ref "aws_vpc.main.id";

    ingress = [
      {
        description = "SSH (stage-2 bootstrap)";
        from_port = 22;
        to_port = 22;
        protocol = "tcp";
        cidr_blocks = [ "0.0.0.0/0" ];
      }
      {
        description = "Tailscale";
        from_port = 41641;
        to_port = 41641;
        protocol = "udp";
        cidr_blocks = [ "0.0.0.0/0" ];
      }
    ];

    egress = [{
      from_port = 0;
      to_port = 0;
      protocol = "-1";
      cidr_blocks = [ "0.0.0.0/0" ];
    }];

    tags = { Name = "nixos-cloud"; };
  };

  # ── Outputs ────────────────────────────────────────────────────────────────
  # (EC2 instance removed — it costs money. Re-add when ready to deploy.)
  output.vpc_id = {
    value = lib.tf.ref "aws_vpc.main.id";
    description = "VPC id for the nixos-cloud network";
  };

  output.subnet_id = {
    value = lib.tf.ref "aws_subnet.main.id";
    description = "Public subnet id";
  };
}
