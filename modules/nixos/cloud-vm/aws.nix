# terranix/aws.nix
{ config, lib, ... }:

let
  cfg = config.cloud.aws;
in {
  options = {
    cloud.aws.hosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          instance_type  = lib.mkOption { type = lib.types.str; default = "t3.micro"; };
          region         = lib.mkOption { type = lib.types.str; };
          nixos_release  = lib.mkOption { type = lib.types.str; default = "25.11"; };
          ssh_public_key = lib.mkOption { type = lib.types.str; default = ""; };
        };
      });
      default     = {};
      description = "AWS hosts to provision";
    };

    # Declare data as valid top-level so mkIf doesn't choke when hosts = {}
    data = lib.mkOption {
      type    = lib.types.attrsOf lib.types.anything;
      default = {};
    };
  };

  config = lib.mkIf (cfg.hosts != {}) {

    terraform.required_providers.aws = {
      source  = "hashicorp/aws";
      version = "~> 5.0";
    };

    provider.aws.region = "eu-west-1";

    # ── AMI lookup ────────────────────────────────────────────────────────────
    data.aws_ami = lib.mapAttrs (name: host: {
      most_recent = true;
      owners      = [ "427812963091" ];
      filter      = [
        { name = "name";                values = [ "nixos/${host.nixos_release}*x86_64-linux" ]; }
        { name = "virtualization-type"; values = [ "hvm" ]; }
      ];
    }) cfg.hosts;

    # ── SSH key pairs ─────────────────────────────────────────────────────────
    resource.aws_key_pair = lib.mapAttrs (name: host: {
      key_name   = "${name}-key";
      public_key = host.ssh_public_key;
    }) cfg.hosts;

    # ── VPC ───────────────────────────────────────────────────────────────────
    resource.aws_vpc = lib.mapAttrs (name: _: {
      cidr_block           = "10.0.0.0/16";
      enable_dns_hostnames = true;
      enable_dns_support   = true;
      tags.Name            = "${name}-vpc";
    }) cfg.hosts;

    resource.aws_internet_gateway = lib.mapAttrs (name: _: {
      vpc_id    = "\${aws_vpc.${name}.id}";
      tags.Name = "${name}-igw";
    }) cfg.hosts;

    resource.aws_subnet = lib.mapAttrs (name: _: {
      vpc_id                  = "\${aws_vpc.${name}.id}";
      cidr_block              = "10.0.1.0/24";
      map_public_ip_on_launch = true;
      tags.Name               = "${name}-public";
    }) cfg.hosts;

    resource.aws_route_table = lib.mapAttrs (name: _: {
      vpc_id = "\${aws_vpc.${name}.id}";
      route  = [{
        cidr_block = "0.0.0.0/0";
        gateway_id = "\${aws_internet_gateway.${name}.id}";
      }];
      tags.Name = "${name}-rt";
    }) cfg.hosts;

    resource.aws_route_table_association = lib.mapAttrs (name: _: {
      subnet_id      = "\${aws_subnet.${name}.id}";
      route_table_id = "\${aws_route_table.${name}.id}";
    }) cfg.hosts;

    # ── Security group ────────────────────────────────────────────────────────
    resource.aws_security_group = lib.mapAttrs (name: _: {
      name   = "${name}-sg";
      vpc_id = "\${aws_vpc.${name}.id}";
      ingress = [
        { description = "SSH";   from_port = 22;  to_port = 22;  protocol = "tcp"; cidr_blocks = [ "0.0.0.0/0" ]; ipv6_cidr_blocks = []; prefix_list_ids = []; security_groups = []; self = false; }
        { description = "HTTP";  from_port = 80;  to_port = 80;  protocol = "tcp"; cidr_blocks = [ "0.0.0.0/0" ]; ipv6_cidr_blocks = []; prefix_list_ids = []; security_groups = []; self = false; }
        { description = "HTTPS"; from_port = 443; to_port = 443; protocol = "tcp"; cidr_blocks = [ "0.0.0.0/0" ]; ipv6_cidr_blocks = []; prefix_list_ids = []; security_groups = []; self = false; }
      ];
      egress = [{
        description      = "Allow all outbound";
        from_port        = 0;
        to_port          = 0;
        protocol         = "-1";
        cidr_blocks      = [ "0.0.0.0/0" ];
        ipv6_cidr_blocks = [];
        prefix_list_ids  = [];
        security_groups  = [];
        self             = false;
      }];
      tags.Name = "${name}-sg";
    }) cfg.hosts;

    # ── EC2 instance ──────────────────────────────────────────────────────────
    resource.aws_instance = lib.mapAttrs (name: host: {
      ami                    = "\${data.aws_ami.${name}.id}";
      instance_type          = host.instance_type;
      subnet_id              = "\${aws_subnet.${name}.id}";
      vpc_security_group_ids = [ "\${aws_security_group.${name}.id}" ];
      key_name               = "\${aws_key_pair.${name}.key_name}";
      root_block_device      = [{
        volume_size = 20;
        volume_type = "gp3";
      }];
      tags.Name = name;
    }) cfg.hosts;

    # ── Elastic IP ────────────────────────────────────────────────────────────
    resource.aws_eip = lib.mapAttrs (name: _: {
      instance  = "\${aws_instance.${name}.id}";
      domain    = "vpc";
      tags.Name = "${name}-eip";
    }) cfg.hosts;

    # ── Outputs ───────────────────────────────────────────────────────────────
    output = lib.mapAttrs (name: _: {
      value = "\${aws_eip.${name}.public_ip}";
    }) cfg.hosts;
  };
}