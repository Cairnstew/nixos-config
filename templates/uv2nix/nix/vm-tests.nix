{ self, nixpkgs, system ? "x86_64-linux" }:

let
  pkgs = nixpkgs.legacyPackages.${system};
in

{
  basic = pkgs.testers.runNixOSTest {
    name = "uv2nix-template-basic";
    nodes.machine = { ... }: {
      imports = [ self.nixosModules.default ];
      services.uv2nix-template.enable = true;
    };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("test -f /etc/uv2nix-template/config.json")
      machine.succeed("uv2nix-template --help")
    '';
  };
}
