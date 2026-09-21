{ config, lib, inputs, ... }: {
  perSystem = { pkgs, system, ... }:
    let
      ntlib = import "${inputs.nixtest}/lib" { inherit pkgs; };
      testDir = "${inputs.self}/tests";

      # Real evaluated modelFallback chains from the desktop host's
      # home-manager config (modules/nixos/homeManager/config.nix). Passed
      # into the test files so tests/opencode-model-fallback_test.nix builds
      # its fixtures from the LIVE config instead of hand-copied chain shapes
      # (kills fixture drift; the deployed ~/.config/opencode/model-fallback.json
      # is builtins.toJSON { chains = ... } of exactly this value).
      realChains =
        config.flake.nixosConfigurations.desktop.config.home-manager.users."seanc".my.programs.opencode.modelFallback.chains;

      testFiles =
        let
          dirContents = builtins.tryEval (builtins.readDir testDir);
        in
        if dirContents.success then
          builtins.filter (n: builtins.match ".*_test\\.nix" n != null)
            (builtins.attrNames dirContents.value)
        else [ ];

      allSuites = builtins.foldl'
        (acc: f:
          let
            mod = import "${testDir}/${f}" { inherit pkgs lib realChains; };
          in
          acc // (mod.suites or { })
        )
        { }
        testFiles;

      testCfg = ntlib.mkNixtestConfig {
        modules = [{ suites = allSuites; }];
        args = { inherit pkgs ntlib; };
      };
    in
    {
      packages = lib.optionalAttrs (testFiles != [ ]) {
        nixtests = testCfg.finalConfigJson;
        nixtests-run = testCfg.app;
      };
    };
}
