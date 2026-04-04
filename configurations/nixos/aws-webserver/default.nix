{ config, flake, pkgs, lib, ... }:

let
  # ── Short aliases ───────────────────────────────────────
  me   = flake.config.me;
  user = me.username;
  self = flake.inputs.self;
in
{
  my.cloud-vm = {
   enable = true;
    provider = "aws";
    profile = "web";
  };

  networking.hostName = "aws-webserver";
}