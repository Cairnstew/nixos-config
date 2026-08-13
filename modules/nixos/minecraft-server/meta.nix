{
  name = "minecraft-server";
  description = "Declarative Minecraft dedicated servers via nix-minecraft (vanilla/fabric/neoforge/paper/velocity) with zip-drop, packwiz2nix and fetchModrinthModpack modpack provisioning and per-server web consoles";
  category = "gaming";
  tags = [ "gaming" "minecraft" "server" "neoforge" "fabric" "modpack" "packwiz" "zip" "ttyd" "opencode" ];
  provides = [ "my.services.minecraftServer" ];
  expects = [ "my.services.monitoring" "my.services.proxy" ];
  complexity = "complex";
  tested = true;
  homepage = "https://github.com/Infinidoge/nix-minecraft";
  maintainer = "seanc";
}
