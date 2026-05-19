---
name: zig-development
description: Zig development with build.zig and Nix
---

## What I do

Guide Zig development within a Nix flake environment.

## Project Structure

```
.
├── build.zig           # Zig build script
├── src/
│   └── main.zig        # Entry point
├── flake.nix           # Nix flake
└── .envrc              # direnv integration
```

## Common Tasks

### Initialize project

```bash
zig init
```

### Build the project

```bash
zig build
# Or with Nix
nix build
```

### Run the application

```bash
zig build run
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
zig build test
```

### Format code

```bash
zig fmt src/
```

## Key Tools Available

- `zig` - Zig compiler and build system
- `zls` - Zig language server

## build.zig Basics

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
```

## Adding Dependencies

With Zig 0.11+, use the package manager:

```bash
zig fetch --save=pkgname https://example.com/package.tar.gz
```

Then in build.zig:
```zig
const dep = b.dependency("pkgname", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("pkgname", dep.module("pkgname"));
```

## Cross-compilation

Zig excels at cross-compilation:

```bash
zig build -Dtarget=x86_64-windows
zig build -Dtarget=aarch64-macos
zig build -Dtarget=wasm32-freestanding
```

## Nix Build Output

The flake builds to `zig-out/bin/`. To customize:

```nix
installPhase = ''
  mkdir -p $out/bin
  cp zig-out/bin/* $out/bin/
'';
```

## Tips

1. **Comptime**: Leverage Zig's compile-time execution
2. **Allocator**: Always pass allocators explicitly
3. **Error handling**: Use error unions `!T`
4. **C interop**: Use `@cImport` and `@cInclude`
5. **Documentation**: Run `zig build --prominent-compile-errors` for clarity
