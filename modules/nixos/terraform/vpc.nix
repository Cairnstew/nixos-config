# terraform/vpc.nix
{ config, lib, ... }:

let
  inherit (lib)
    mkOption types mkIf mapAttrs foldl'
    recursiveUpdate optionalAttrs imap0 attrValues;

  vpcOpts = types.submodule ({ name, config, ... }: {
    options = {
      cidr = mkOption {
        type    = types.str;
        default = "10.0.0.0/16";
      };

      availabilityZones = mkOption {
        type        = types.listOf types.str;
        description = "One public + one private subnet is created per AZ.";
        example     = [ "eu-west-1a" "eu-west-1b" ];
      };

      publicSubnetCidrs = mkOption {
        type    = types.listOf types.str;
        description = "Override auto-generated public CIDRs.";
      };

      privateSubnetCidrs = mkOption {
        type    = types.listOf types.str;
        description = "Override auto-generated private CIDRs.";
      };

      natGateway = mkOption {
        type    = types.enum [ "single" "perAz" "none" ];
        default = "single";
        description = ''
          single — one NAT GW in AZ 0 (cheaper)
          perAz  — one NAT GW per AZ (HA)
          none   — no NAT GW; private subnets have no internet egress
        '';
      };

      enableDnsHostnames = mkOption { type = types.bool; default = true; };
      enableDnsSupport   = mkOption { type = types.bool; default = true; };

      tags = mkOption {
        type    = types.attrsOf types.str;
        default = {};
      };

      ref = mkOption {
        type     = types.attrs;
        readOnly = true;
        description = "Terraform interpolation strings — pass to services.ecsFargate.vpc.";
      };
    };

    config = let
      n    = name;
      nAzs = builtins.length config.availabilityZones;
      baseOctet = lib.elemAt (lib.splitString "." config.cidr) 1;
    in {
      # Use mkDefault so these can be overridden by the user without recursion
      publicSubnetCidrs = lib.mkDefault (lib.genList (i: "10.${baseOctet}.${toString i}.0/24") nAzs);
      privateSubnetCidrs = lib.mkDefault (lib.genList (i: "10.${baseOctet}.${toString (i + 10)}.0/24") nAzs);

      ref = {
        id = "\${aws_vpc.${n}.id}";
        privateSubnetIds = lib.genList
          (i: "\${aws_subnet.${n}_private_${toString i}.id}") nAzs;
        publicSubnetIds = lib.genList
          (i: "\${aws_subnet.${n}_public_${toString i}.id}") nAzs;
      };
    };
  });

in
{
  options.networking.vpcs = mkOption {
    type    = types.attrsOf vpcOpts;
    default = {};
  };

  config =
    let
      vpcResources = mapAttrs (name: vpc:
        let
          n      = name;
          nAzs   = builtins.length vpc.availabilityZones;
          azList = vpc.availabilityZones;

          natIndices =
            if vpc.natGateway == "perAz"        then lib.genList (i: i) nAzs
            else if vpc.natGateway == "single"  then [ 0 ]
            else [];

        in foldl' recursiveUpdate {} [

          # VPC
          { resource.aws_vpc.${n} = {
              cidr_block           = vpc.cidr;
              enable_dns_hostnames = vpc.enableDnsHostnames;
              enable_dns_support   = vpc.enableDnsSupport;
              tags                 = vpc.tags // { Name = n; };
            };
          }

          # Internet Gateway
          { resource.aws_internet_gateway.${n} = {
              vpc_id = "\${aws_vpc.${n}.id}";
              tags   = vpc.tags // { Name = "${n}-igw"; };
            };
          }

          # Public subnets
          (foldl' recursiveUpdate {} (imap0 (i: az: {
            resource.aws_subnet."${n}_public_${toString i}" = {
              vpc_id                  = "\${aws_vpc.${n}.id}";
              cidr_block              = builtins.elemAt vpc.publicSubnetCidrs i;
              availability_zone       = az;
              map_public_ip_on_launch = true;
              tags = vpc.tags // { Name = "${n}-public-${toString i}"; Tier = "public"; };
            };
          }) azList))

          # Private subnets
          (foldl' recursiveUpdate {} (imap0 (i: az: {
            resource.aws_subnet."${n}_private_${toString i}" = {
              vpc_id            = "\${aws_vpc.${n}.id}";
              cidr_block        = builtins.elemAt vpc.privateSubnetCidrs i;
              availability_zone = az;
              tags = vpc.tags // { Name = "${n}-private-${toString i}"; Tier = "private"; };
            };
          }) azList))

          # EIPs + NAT Gateways
          (foldl' recursiveUpdate {} (map (i: {
            resource.aws_eip."${n}_nat_${toString i}" = {
              domain     = "vpc";
              depends_on = [ "aws_internet_gateway.${n}" ];
              tags       = vpc.tags // { Name = "${n}-nat-eip-${toString i}"; };
            };
            resource.aws_nat_gateway."${n}_${toString i}" = {
              allocation_id = "\${aws_eip.${n}_nat_${toString i}.id}";
              subnet_id     = "\${aws_subnet.${n}_public_${toString i}.id}";
              depends_on    = [ "aws_internet_gateway.${n}" ];
              tags          = vpc.tags // { Name = "${n}-nat-${toString i}"; };
            };
          }) natIndices))

          # Public route table
          { resource.aws_route_table."${n}_public" = {
              vpc_id = "\${aws_vpc.${n}.id}";
              tags   = vpc.tags // { Name = "${n}-public-rt"; };
              route  = [{ cidr_block = "0.0.0.0/0"; gateway_id = "\${aws_internet_gateway.${n}.id}"; }];
            };
          }
          (foldl' recursiveUpdate {} (imap0 (i: _: {
            resource.aws_route_table_association."${n}_public_${toString i}" = {
              subnet_id      = "\${aws_subnet.${n}_public_${toString i}.id}";
              route_table_id = "\${aws_route_table.${n}_public.id}";
            };
          }) azList))

          # Private route tables (one per AZ)
          (foldl' recursiveUpdate {} (imap0 (i: _:
            let
              natIdx = if vpc.natGateway == "perAz" then i else 0;
              hasNat = vpc.natGateway != "none";
            in {
              resource.aws_route_table."${n}_private_${toString i}" = {
                vpc_id = "\${aws_vpc.${n}.id}";
                tags   = vpc.tags // { Name = "${n}-private-rt-${toString i}"; };
              } // optionalAttrs hasNat {
                route = [{ cidr_block = "0.0.0.0/0"; nat_gateway_id = "\${aws_nat_gateway.${n}_${toString natIdx}.id}"; }];
              };
              resource.aws_route_table_association."${n}_private_${toString i}" = {
                subnet_id      = "\${aws_subnet.${n}_private_${toString i}.id}";
                route_table_id = "\${aws_route_table.${n}_private_${toString i}.id}";
              };
            }
          ) azList))

          # Outputs
          {
            output."${n}_vpc_id".value             = "\${aws_vpc.${n}.id}";
            output."${n}_public_subnet_ids".value  =
              lib.genList (i: "\${aws_subnet.${n}_public_${toString i}.id}") nAzs;
            output."${n}_private_subnet_ids".value =
              lib.genList (i: "\${aws_subnet.${n}_private_${toString i}.id}") nAzs;
          }

        ]
      ) config.networking.vpcs;

    in
    foldl' recursiveUpdate {} (attrValues vpcResources);
}