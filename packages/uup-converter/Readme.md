# uup-converter (Nix package)

This repository provides a **Nix package and flake** for **uup-converter**, a tool that converts Windows UUP (Unified Update Platform) downloads into installation media such as **ISO** or **WIM** images.

This repository focuses on **packaging only**. For usage details, supported flags, and licensing, refer to the upstream project.

---

## Upstream

- **Upstream project:** [https://git.uupdump.net/uup-dump/converter](https://git.uupdump.net/uup-dump/converter)  
- **This repository:** [https://github.com/Cairnstew/uup-converter](https://github.com/Cairnstew/uup-converter)  
- **License:** See upstream for license details  

---

## Requirements

- Linux
- Nix
- A prepared UUP download directory (this tool **does not** download UUP files)

All runtime dependencies are provided by Nix.

---

## Usage with flakes (recommended)

### Build the package

```bash
nix build github:Cairnstew/uup-converter#uup-converter
````

### Run the tool

```bash
nix run github:Cairnstew/uup-converter#uup-converter -- --help
```

> The `--` separates Nix arguments from the program arguments.

---

## Local / non-flake build (legacy)

From the repository root:

```bash
nix-build -A uup-converter
```

This creates a `./result` symlink. The binary will be available at:

```bash
./result/bin/uup-converter
```

---

## Installation

### Per-user (legacy)

```bash
nix-env -f . -iA uup-converter
```

### Declarative NixOS

Add to your system configuration:

```nix
environment.systemPackages = [ pkgs.uup-converter ];
```

Or use `home-manager`:

```nix
home.packages = [ pkgs.uup-converter ];
```

---

## Basic usage

Run `--help` to see all available options:

```bash
uup-converter --help
```

Example usage:

```bash
# Convert a UUP folder into an ISO
uup-converter -i ./uup_download -o ./Windows.iso

# Produce a WIM image
uup-converter -i ./uup_download -w ./install.wim
```

> The input directory must already contain a valid UUP file layout produced by a UUP downloader.

---

## Notes

* Available flags depend on the upstream revision packaged here.
* Always validate generated ISOs or WIMs in a VM or deployment tooling before production use.
* This package **wraps** the upstream tool; it does not modify behavior beyond providing dependencies.

---
