{ config, lib, inputs, ... }: {
  perSystem = { pkgs, system, ... }:
    let
      ntlib = import "${inputs.nixtest}/lib" { inherit pkgs; };
      testDir = "${inputs.self}/tests";

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
            mod = import "${testDir}/${f}" { inherit pkgs lib; };
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
