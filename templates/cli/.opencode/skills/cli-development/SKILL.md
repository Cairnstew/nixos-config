---
name: cli-development
description: Command-line tool development with Nix
---

## What I do

Guide development of command-line tools with argument parsing and proper packaging.

## Project Structure

```
.
├── flake.nix           # Nix flake
├── bin/
│   └── my-cli          # CLI script (optional)
└── .envrc              # direnv integration
```

## Pattern

This template creates a CLI tool using `writeShellApplication` for bash
scripts or full packages for compiled languages.

## Common Tasks

### Modify the CLI

Edit the `text` attribute in `flake.nix`:

```nix
packages.default = pkgs.writeShellApplication {
  name = "my-cli";
  runtimeInputs = with pkgs; [ jq curl ];
  text = ''
    # Your script here
    echo "Hello, $1!"
  '';
};
```

### Add runtime dependencies

Add to `runtimeInputs`:
```nix
runtimeInputs = with pkgs; [ 
  jq 
  curl 
  git 
];
```

### Run the CLI

```bash
nix run
# Or after building
nix build
./result/bin/my-cli
```

### Development shell

```bash
nix develop
# Or with direnv
direnv allow
```

## For Compiled CLIs

Replace `writeShellApplication` with proper package:

```nix
packages.default = pkgs.rustPlatform.buildRustPackage {
  pname = "my-cli";
  version = "0.1.0";
  src = ./.;
  cargoSha256 = pkgs.lib.fakeSha256;
};
```

## Argument Parsing

For bash, use `getopts`:
```bash
while getopts "hvn:" opt; do
  case $opt in
    h) show_help; exit 0 ;;
    v) verbose=true ;;
    n) name="$OPTARG" ;;
    *) exit 1 ;;
  esac
done
```

Or use `argbash` for more complex parsing.

## Subcommands Pattern

```bash
case "''${1:-}" in
  init)
    shift
    cmd_init "$@"
    ;;
  build)
    shift
    cmd_build "$@"
    ;;
  *)
    usage
    exit 1
    ;;
esac
```

## Tips

1. **Shellcheck**: Always enable shellcheck for bash scripts
2. **Help text**: Include `--help` / `-h` in every CLI
3. **Exit codes**: Use appropriate exit codes (0=success, 1=error)
4. **Logging**: Use `echo >&2` for stderr messages
5. **Strict mode**: Always use `set -euo pipefail`
