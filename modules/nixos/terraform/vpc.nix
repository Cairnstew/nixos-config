# terraform/vpc.nix
{ ... }:

{
  resource = {
    # ── VPC ────────────────────────────────────────────────────────────────
    aws_vpc.main = {
      cidr_block           = "10.0.0.0/16";
      enable_dns_hostnames = true;
      enable_dns_support   = true;
      tags.Name            = "main";
    };

    # ── Internet gateway ───────────────────────────────────────────────────
    aws_internet_gateway.main = {
      vpc_id   = "\${aws_vpc.main.id}";
      tags.Name = "main";
    };

    # ── Public subnet ──────────────────────────────────────────────────────
    aws_subnet.public = {
      vpc_id                  = "\${aws_vpc.main.id}";
      cidr_block              = "10.0.1.0/24";
      map_public_ip_on_launch = true;
      tags.Name               = "public";
    };

    # ── Route table ────────────────────────────────────────────────────────
    aws_route_table.public = {
      vpc_id = "\${aws_vpc.main.id}";
      route = [{
        cidr_block = "0.0.0.0/0";
        gateway_id = "\${aws_internet_gateway.main.id}";
      }];
      tags.Name = "public";
    };

    aws_route_table_association.public = {
      subnet_id      = "\${aws_subnet.public.id}";
      route_table_id = "\${aws_route_table.public.id}";
    };

    # ── Security group ─────────────────────────────────────────────────────
    aws_security_group.main = {
      name        = "main";
      description = "Allow SSH and all egress";
      vpc_id      = "\${aws_vpc.main.id}";

      ingress = [{
        description      = "SSH";
        from_port        = 22;
        to_port          = 22;
        protocol         = "tcp";
        cidr_blocks      = [ "0.0.0.0/0" ];
        ipv6_cidr_blocks = [];
        prefix_list_ids  = [];
        security_groups  = [];
        self             = false;
      }];

      egress = [{
        description      = "All outbound";
        from_port        = 0;
        to_port          = 0;
        protocol         = "-1";
        cidr_blocks      = [ "0.0.0.0/0" ];
        ipv6_cidr_blocks = [ "::/0" ];
        prefix_list_ids  = [];
        security_groups  = [];
        self             = false;
      }];

      tags.Name = "main";
    };
  };
}
