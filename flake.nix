{
  description = "Srid's NixOS / nix-darwin configuration";

  nixConfig = {
    substituters = [
      "https://cache.nixos-cuda.org/"
      "https://cache.nixos.org/"
      "https://nix-community.cachix.org"
      "https://cairnstew-nixos-config-cache.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos-cuda.org-1:dykfIgNYfi2cKCfb4xMBbOjlzFnEiCsHxlXLjfXDwOY="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="

      # Your cache
      "cairnstew-nixos-config-cache.cachix.org-1:1150paajFeK18p7Eie/4L8iews3pbFbVp3eOxkmXar4="
    ];
  };

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";

    # Principle inputs

    # RETARDED POLITICAL UPSTREAM BREAKS CACHE OFTEN
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";


    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixos-unified.url = "github:srid/nixos-unified";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    nuenv.url = "github:hallettj/nuenv/writeShellApplication";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    auto-cpufreq = {
      url = "github:AdnanHodzic/auto-cpufreq";
      inputs.nixpkgs.follows = "nixpkgs"; # important to avoid version mismatch
    };

    terranix = {
      url = "github:terranix/terranix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Software inputs
    github-nix-ci.url = "github:juspay/github-nix-ci";
    nixos-vscode-server.flake = false;
    nixos-vscode-server.url = "github:nix-community/nixos-vscode-server";
    flake-utils.url = "github:numtide/flake-utils";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    try.url = "github:tobi/try";
    vira.url = "github:juspay/vira";
    nix-ai-tools.url = "github:numtide/nix-ai-tools";
    nix-ai-tools.inputs.nixpkgs.follows = "nixpkgs";
    landrun-nix.url = "github:srid/landrun-nix";
    hyprland.url = "github:hyprwm/Hyprland";
    compose2nix.url = "github:aksiksi/compose2nix";
    compose2nix.inputs.nixpkgs.follows = "nixpkgs";

    # ISOS

    # Pre-built Windows ISOs from GitHub releases
    windows-iso-src = {
      url = "github:Cairnstew/uup-dump-build-and-get-windows-iso";
      flake = true;
    };

    gparted-iso = {
      url = "https://downloads.sourceforge.net/gparted/gparted-live-1.6.0-1-amd64.iso?sha256=18v0w9pcdyqx69w82paadgcniii2zcm52rn2h3fhasp7nr0pdims";
      flake = false;
    };

    # Windows unattended answer file generator
    GenerateAnswerFile = {
      url = "github:Cairnstew/GenerateAnswerFile";
    };

    # DSC v3 YAML configuration generation (Nix → Windows DSC)
    dscnix = {
      url = "github:Cairnstew/dscnix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Neovim
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    # Emacs
    nix-doom-emacs-unstraightened.url = "github:marienz/nix-doom-emacs-unstraightened";
    nix-doom-emacs-unstraightened.inputs.nixpkgs.follows = "nixpkgs";

    zig-overlay.url = "github:mitchellh/zig-overlay";

    # Terminal
    ghostty = {
      url = "github:ghostty-org/ghostty/v1.2.3";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        zig.follows = "zig-overlay";
      };
    };

    # Devshell
    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.flake = false;
  };

  # Wired using https://nixos-unified.org/autowiring.html
  outputs = inputs@{ self, ... }:
    inputs.flake-parts.lib.mkFlake { inherit inputs; }
    ({ config, lib, ... }: {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      imports =
        let
          files = builtins.attrNames (builtins.readDir ./modules/flake-parts);
          nixFiles = builtins.filter (fn: builtins.match ".*\\.nix" fn != null) files;
        in
        builtins.map (fn: ./modules/flake-parts/${fn}) nixFiles;


      # ── Ventoy: ISOs + config for multi-boot USB ───────────────────
      ventoy = {
        #device = "/dev/sdb";
        settings = {
          control = [
            { VTOY_DEFAULT_MENU_MODE = "0"; }
            { VTOY_TREE_VIEW_MENU_STYLE = "0"; }
            { VTOY_DEFAULT_SEARCH_ROOT = "/iso"; }
            { VTOY_FILT_DOT_UNDERSCORE_FILE = "1"; }
            { VTOY_WIN11_BYPASS_CHECK = "1"; }
            { VTOY_WIN11_BYPASS_NRO = "1"; }
          ];
          menu_class = [
            { parent = "/iso/windows"; class = "windows"; }
            { parent = "/iso/linux";   class = "linux"; }
          ];
          # Friendly names in the boot menu
          menu_alias = [
            { image = "/iso/windows/22631.7079.23H2.PRO.X64.EN.iso"; alias = "Windows 11 23H2 Pro"; }
            { dir   = "/iso/linux";   alias = "[ Linux ISOs ]"; }
          ];
          # Custom GRUB menu extension (F6 in Ventoy menu)
          # grubConfig = ./ventoy_grub.cfg;
        };

        installOptions = {
          # secureBoot = true;
          # gpt = true;
        };

        answerFileSettings = {
          username = config.me.username;
          hostname = config.me.username + "-win";
          diskId = "0";
        };

        isos = {
          win11-23h2 = {
            source = inputs.windows-iso-src.packages.x86_64-linux."windows-iso-22631.7079.23H2.PRO.X64.EN";
            target = "/iso/windows/22631.7079.23H2.PRO.X64.EN.iso";
          };
          nixos-installer = {
            source = self.packages.x86_64-linux.nixos-installer;
            target = "/iso/linux/nixos-installer.iso";
          };
          gparted = {
            source = inputs.gparted-iso;
            target = "/iso/linux/gparted-live-1.6.0-1-amd64.iso";
          };
        };

        # Extra files deployed alongside ISOs — answer file profiles
        deployFiles = inputs.nixpkgs.lib.mapAttrs' (n: v:
          inputs.nixpkgs.lib.nameValuePair "windows-answer-${n}" {
            source = self.packages.x86_64-linux."windows-answ-pro-${n}";
            target = "/ventoy/scripts/${n}.xml";
          }
        ) {
          dev      = {};
          minimal  = {};
          domain   = {};
          kiosk    = {};
          dual-boot = {};
        };

        # Windows auto-install: pick from multiple answer profiles at boot
        settings.auto_install = [
          {
            image = "/iso/windows/22631.7079.23H2.PRO.X64.EN.iso";
            template = [
              "/ventoy/scripts/dev.xml"
              "/ventoy/scripts/minimal.xml"
              "/ventoy/scripts/domain.xml"
              "/ventoy/scripts/kiosk.xml"
              "/ventoy/scripts/dual-boot.xml"
            ];
          }
        ];
      };

      perSystem = { lib, system, ... }: {
        # Make our overlay available to the devShell
        # "Flake parts does not yet come with an endorsed module that initializes the pkgs argument.""
        # So we must do this manually; https://flake.parts/overlays#consuming-an-overlay
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = lib.attrValues self.overlays;
          config.allowUnfree = true;
        };
      };
    });
}
