{
  name = "graphics";
  description = "GPU and graphics driver configuration (NVIDIA, AMD, Mesa, Vulkan, X server)";
  category = "hardware";
  tags = [ "graphics" "gpu" "nvidia" "amd" "mesa" "vulkan" "xserver" ];
  provides = [
    "my.hardware.graphics"
    "my.hardware.xserver"
    "my.hardware.gpu.nvidia"
    "my.hardware.gpu.amd"
    "my.hardware.gpu.mesa"
    "my.hardware.vulkan"
  ];
  expects = [ "my.secrets" ];
  complexity = "complex";
  tested = true;
  maintainer = "seanc";
  homepage = "https://nixos.wiki/wiki/Graphics";
}
