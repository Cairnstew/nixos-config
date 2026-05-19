---
name: go-development
description: Go development with modules and Nix
---

## What I do

Guide Go development within a Nix flake environment.

## Project Structure

```
.
├── go.mod              # Go module file
├── go.sum              # Go checksums (generated)
├── main.go             # Entry point
├── flake.nix           # Nix flake
└── .envrc              # direnv integration
```

## Common Tasks

### Initialize module

```bash
go mod init github.com/username/project
```

### Add dependencies

```bash
go get github.com/user/package
```

### Build the project

```bash
nix build
# Or with go
go build -o myapp
```

### Run the application

```bash
go run .
# Or with Nix
nix run
```

### Development shell

```bash
nix develop
# Or with direnv
direnv allow
```

### Run tests

```bash
go test ./...
```

### Format code

```bash
go fmt ./...
```

### Vet code

```bash
go vet ./...
```

## Key Tools Available

- `go` - Go compiler and toolchain
- `gopls` - Language server
- `gotools` - Additional tools (godoc, goimports, etc.)

## Build Configuration

The flake uses `buildGoModule` which requires `vendorHash`:

1. First build will fail with expected hash
2. Set `vendorHash = pkgs.lib.fakeSha256;` temporarily
3. Run `nix build` and copy the actual hash
4. Update `vendorHash` with the correct value

Or use `gomod2nix` for automatic vendor hash management.

## Cross-compilation

Build for different platforms:

```nix
packages = {
  myapp-linux = pkgs.buildGoModule {
    # ...
    GOOS = "linux";
    GOARCH = "amd64";
  };
  myapp-darwin = pkgs.buildGoModule {
    # ...
    GOOS = "darwin";
    GOARCH = "arm64";
  };
};
```

## Tips

1. **Vendoring**: Run `go mod vendor` to create `vendor/` directory
2. **Tidy**: Run `go mod tidy` to clean up dependencies
3. **Private repos**: Set `GOPRIVATE` environment variable
4. **Static builds**: Set `CGO_ENABLED = 0` for static binaries
