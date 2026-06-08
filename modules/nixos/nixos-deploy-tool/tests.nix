{ config, lib, flake, pkgs, ... }:
{
  my.testing.vmTests.nixos-deploy-tool = {
    enable = true;
    name = "nixos-deploy-tool";
    nodes.machine = { ... }: {
      _module.args.flake = flake;

      # The local default.nix imports the upstream module internally
      imports = [ ../default.nix ];

      my.services.nixos-deploy-tool = {
        enable = true;
        settings = {
          logLevel = "debug";
          flakeRoot = "/etc/nixos";
        };
      };

      system.stateVersion = "25.05";
    };
    testScript = ''
      machine.wait_for_unit("default.target")

      # Config file written by the upstream module
      machine.succeed("test -f /etc/nixos-deploy/config.json")
      machine.succeed("grep -q 'debug' /etc/nixos-deploy/config.json")
      machine.succeed("grep -q '/etc/nixos' /etc/nixos-deploy/config.json")

      # Service unit is registered and references the real binary
      machine.succeed("systemctl cat nixos-deploy-tool.service | grep /bin/nixos-deploy")

      # Auto-wired paths are present (agenix-manager, nixos-anywhere, age)
      machine.succeed("grep -q 'agenix-manager' /etc/nixos-deploy/config.json")
      machine.succeed("grep -q 'nixos-anywhere' /etc/nixos-deploy/config.json")
      machine.succeed("grep -q 'age' /etc/nixos-deploy/config.json")

      print("nixos-deploy-tool VM test: PASS")
    '';
    meta = {
      description = "Validates nixos-deploy-tool my.* wrapper + upstream module: settings, auto-wired paths, systemd service";
      module = "nixos-deploy-tool";
    };
  };
}
