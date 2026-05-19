---
name: nix-library-dev
description: Develop Nix libraries with functions and tests
---

## What I do

Guide development of reusable Nix libraries.

## Project Structure

```
.
├── flake.nix           # Nix flake
├── lib/
│   ├── default.nix     # Library entry point
│   ├── functions.nix   # Library functions
│   └── tests.nix       # Library tests
└── .envrc              # direnv integration
```

## Library Structure

### lib/default.nix

```nix
{ lib }:
let
  functions = import ./functions.nix { inherit lib; };
in
{
  inherit (functions)
    myFunction
    anotherFunction
  ;
}
```

### lib/functions.nix

```nix
{ lib }:
{
  # Example function
  myFunction = x: x + 1;
  
  # Function with documentation
  anotherFunction = { arg1, arg2 }:
    lib.concatStringsSep "-" [ arg1 arg2 ];
}
```

### lib/tests.nix

```nix
{ lib, myLib }:
{
  test-myFunction = {
    expr = myLib.myFunction 5;
    expected = 6;
  };
  
  test-anotherFunction = {
    expr = myLib.anotherFunction { arg1 = "a"; arg2 = "b"; };
    expected = "a-b";
  };
}
```

## Exporting the Library

In `flake.nix`:

```nix
{
  outputs = inputs@{ self, nixpkgs, ... }:
  {
    lib = import ./lib { inherit (nixpkgs) lib; };
  };
}
```

## Using the Library

### Within the same flake

```nix
perSystem = { ... }: {
  packages.example = pkgs.writeText "example" 
    (self.lib.myFunction "hello");
};
```

### From another flake

```nix
{
  inputs.mylib.url = "github:user/repo";
  
  outputs = { mylib, ... }: {
    result = mylib.lib.myFunction 42;
  };
}
```

## Testing

### Run library tests

```bash
nix build .#checks.x86_64-linux.lib-tests
```

### Test in REPL

```bash
nix repl
nix-repl> :lf .
nix-repl> lib.myFunction 5
6
```

## Best Practices

1. **Use `lib` functions**: Leverage `nixpkgs/lib` for common operations
2. **Document functions**: Add comments explaining inputs/outputs
3. **Type checking**: Use `lib.types` for validation
4. **Testing**: Always write tests for library functions
5. **Compose**: Build complex functions from simple ones

## Example: String Utilities

```nix
{ lib }:
let
  inherit (lib.strings) toUpper toLower;
in
{
  # Convert snake_case to camelCase
  toCamelCase = str:
    let
      parts = lib.splitString "_" str;
      capitalized = map lib.capitalize (tail parts);
    in
      head parts + concatStrings capitalized;
      
  # Safe string truncation
  truncate = maxLen: str:
    if builtins.stringLength str > maxLen
    then builtins.substring 0 maxLen str + "..."
    else str;
}
```
