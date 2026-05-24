# Terraform / Terranix

GCP GPU VM deployment configuration for terranix.

## Usage

This is consumed by terranix, not by NixOS directly:

```shell
nix run .#tf -- plan
nix run .#tf -- apply
```

See `modules/flake-parts/terranix.nix` for the integration layer.
