{ config, lib, ... }:

let
  cfg = config.my.programs.obsidian;

  enabledPlugins = lib.filterAttrs (_: plugin: plugin.enable) cfg.plugins;

  pluginAssertions = lib.mapAttrsToList
    (id: plugin: {
      assertion =
        plugin.version != ""
        && plugin.repo != ""
        && lib.hasInfix "/" plugin.repo
        && plugin.mainJsHash != ""
        && plugin.manifestHash != "";
      message = ''
        my.programs.obsidian.plugins."${id}" is enabled but incomplete: set
        version, repo ("owner/name"), mainJsHash and manifestHash.
      '';
    })
    enabledPlugins;
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.defaultDirectory != "";
        message = "my.programs.obsidian.defaultDirectory must not be empty.";
      }
      {
        assertion = !cfg.repo.enable || cfg.repo.url != "";
        message = "my.programs.obsidian.repo.url must be set when repo.enable is true.";
      }
    ] ++ pluginAssertions;
  };
}
