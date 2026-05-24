{ config, lib, ... }:
{
  assertions = [
    {
      assertion = true;
      message = "terraform module is a terranix config; no NixOS assertions needed.";
    }
  ];
}
