{
  name = "cachix-push";
  description = "Periodically push Nix store paths (system closure) to a Cachix binary cache";
  category = "ci";
  tags = [ "cachix" "cache" "binary-cache" "ci" "push" ];
  provides = [ "my.services.cachix-push" ];
  expects = [ "my.secrets" ];
  complexity = "simple";
  tested = true;
  maintainer = "seanc";
  homepage = "https://www.cachix.org";
}
