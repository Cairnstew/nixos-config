{ pkgs, lib, ... }: {
  suites."core-tests" = {
    pos = __curPos;
    tests = [
      {
        name = "hello-world";
        expected = "hello";
        actual = "hello";
      }
      {
        name = "math-works";
        expected = 4;
        actual = 2 + 2;
      }
      {
        name = "null-is-null";
        type = "unit";
        expected = null;
        actual = null;
      }
      {
        name = "nixpkgs-has-hello";
        type = "unit";
        expected = true;
        actual = lib.isDerivation pkgs.hello;
      }
    ];
  };
}
