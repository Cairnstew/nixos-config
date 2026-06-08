{ inputs, lib, ... }: {
  perSystem = { pkgs, system, ... }: lib.optionalAttrs (builtins.elem system [ "x86_64-linux" "aarch64-linux" ]) {
    devShells.deploy-tool = pkgs.mkShell {
      name = "deploy-tool";
      packages = [
        inputs.nixos-deploy-tool.packages.${system}.default
        inputs.nixos-anywhere.packages.${system}.default
      ];

      shellHook = ''
        echo ""
        echo "=== Deploy Tool DevShell ==="
        echo "Available: nixos-deploy, nixos-anywhere"
        echo ""
        echo "  nixos-deploy deploy run <host>          → Deploy via nixos-anywhere"
        echo "  nixos-deploy deploy with-keys <host>    → Deploy with pre-generated host key"
        echo "  nixos-deploy deploy wizard <host>       → Interactive deploy"
        echo "  nixos-deploy deploy test <host>         → VM test"
        echo "  nixos-deploy iso [build|list|info]      → ISO operations"
        echo "  nixos-deploy secrets [list|rekey]        → Secret management"
        echo "  nixos-deploy tailscale [auth-key|status] → Tailscale key management"
        echo ""
      '';
    };
  };
}
