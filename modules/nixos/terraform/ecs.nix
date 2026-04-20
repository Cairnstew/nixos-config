# terraform/ecs.nix
{ lib, ... }:

let
  inherit (lib) mkOption mkEnableOption types imap0;

  healthCheckOpts = types.submodule {
    options = {
      path      = mkOption { type = types.str; default = "/"; };
      interval  = mkOption { type = types.int; default = 30; };
      timeout   = mkOption { type = types.int; default = 5; };
      healthy   = mkOption { type = types.int; default = 2; };
      unhealthy = mkOption { type = types.int; default = 3; };
      matcher   = mkOption { type = types.str; default = "200-299"; };
    };
  };

  scalingOpts = types.submodule {
    options = {
      min       = mkOption { type = types.int; default = 1; };
      max       = mkOption { type = types.int; default = 3; };
      cpuTarget = mkOption { type = types.int; default = 70; };
      memTarget = mkOption { type = types.nullOr types.int; default = null; };
    };
  };

  containerOpts = types.submodule {
    options = {
      image            = mkOption { type = types.str; };
      cpu              = mkOption { type = types.int; default = 256; };
      memory           = mkOption { type = types.int; default = 512; };
      port             = mkOption { type = types.nullOr types.int; default = null; };
      public           = mkOption { type = types.bool; default = false; };
      protocol         = mkOption { type = types.enum [ "HTTP" "HTTPS" "TCP" ]; default = "HTTP"; };
      environment      = mkOption { type = types.attrsOf types.str; default = {}; };
      secrets          = mkOption { type = types.attrsOf types.str; default = {}; };
      command          = mkOption { type = types.nullOr (types.listOf types.str); default = null; };
      healthCheck      = mkOption { type = types.nullOr healthCheckOpts; default = null; };
      scaling          = mkOption { type = scalingOpts; default = {}; };
      logRetentionDays = mkOption { type = types.int; default = 14; };
      assignPublicIp   = mkOption { type = types.bool; default = false; };
      taskRoleArn      = mkOption { type = types.nullOr types.str; default = null; };
      extraPolicies    = mkOption { type = types.listOf types.str; default = []; };
    };
  };

in
{
  options.services.ecsFargate = {
    enable      = mkEnableOption "ECS Fargate infrastructure";
    clusterName = mkOption { type = types.str; };
    region      = mkOption { type = types.str; default = "eu-west-1"; };
    tags        = mkOption { type = types.attrsOf types.str; default = {}; };

    vpc = {
      id               = mkOption { type = types.str; };
      privateSubnetIds = mkOption { type = types.listOf types.str; default = []; };
      publicSubnetIds  = mkOption { type = types.listOf types.str; default = []; };
    };

    containers = mkOption {
      type    = types.attrsOf containerOpts;
      default = {};
    };
  };
}