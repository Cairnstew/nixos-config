{
  name = "docker";
  description = "Docker OCI container runtime and daemon configuration with NVIDIA Container Toolkit support";
  category = "virtualisation";
  tags = [ "containers" "docker" "virtualisation" "nvidia" "gpu" ];
  provides = [ "my.virtualisation.docker" ];
  expects = [ "my.secrets" ];
  complexity = "medium";
  tested = true;
  maintainer = "seanc";
  homepage = "https://docs.docker.com";
}
