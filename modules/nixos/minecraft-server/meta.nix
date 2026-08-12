{
  name = "minecraft-server";
  description = "Declarative Minecraft dedicated servers via nix-minecraft (vanilla/fabric/neoforge/paper/velocity) with modpack support";
  category = "gaming";
  tags = [ "gaming" "minecraft" "server" "neoforge" "fabric" "modpack" ];
  provides = [ "my.services.minecraftServer" ];
  expects = [ "my.services.monitoring" ];
  complexity = "medium";
  tested = true;
  homepage = "https://github.com/Infinidoge/nix-minecraft";
  maintainer = "seanc";
}
