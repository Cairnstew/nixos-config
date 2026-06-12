{ config, lib, pkgs, flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
  inherit (flake.config.me) username;
  cfg = config.my.homeManager;
  mcpServersPkgs = inputs.mcp-servers-nix.packages.${pkgs.system};

  betterEmailPkg =
    pkgs.writeShellApplication {
      name = "better-email";
      runtimeInputs = [ pkgs.nodejs ];
      text = ''
        EMAIL_APP_PASSWORD=$(cat ${config.age.secrets.mcp-better-email-password.path})
        export EMAIL_APP_PASSWORD
        exec npx -y @n24q02m/better-email-mcp "$@"
      '';
      meta.description = "MCP server: better-email (IMAP/SMTP for AI agents)";
    };

  # Opencode theme derived from config.nix me.colorScheme
  # Maps semantic UI roles to Base16 color definitions
  opencodeTheme = let
    c = flake.config.me.colorScheme;
  in {
    catppuccin-mocha = {
      defs = {
        inherit (c) base00 base01 base02 base03 base04 base05 base06 base07
                   base08 base09 base0A base0B base0C base0D base0E base0F
                   cursor;
      };
      theme = {
        primary = "base0D"; secondary = "base0C"; accent = "base0E";
        error = "base08";   warning = "base09";   success = "base0B";
        info = "base0D";
        text = "base05"; textMuted = "base04";
        background = "base00"; backgroundPanel = "base01";
        backgroundElement = "base02";
        border = "base03"; borderActive = "base0D"; borderSubtle = "base02";
        diffAdded = "base0B"; diffRemoved = "base08"; diffContext = "base03";
        diffHunkHeader = "base04";
        diffHighlightAdded = "base0B"; diffHighlightRemoved = "base08";
        diffAddedBg = "base02"; diffRemovedBg = "base02"; diffContextBg = "base01";
        diffLineNumber = "base03";
        diffAddedLineNumberBg = "base01"; diffRemovedLineNumberBg = "base01";
        markdownText = "base05"; markdownHeading = "base0D";
        markdownLink = "base0C"; markdownLinkText = "base0D";
        markdownCode = "base0B"; markdownBlockQuote = "base03";
        markdownEmph = "base09"; markdownStrong = "base0A";
        markdownHorizontalRule = "base03";
        markdownListItem = "base0D"; markdownListEnumeration = "base0C";
        markdownImage = "base0C"; markdownImageText = "base0E";
        markdownCodeBlock = "base05";
        syntaxComment = "base03"; syntaxKeyword = "base0E";
        syntaxFunction = "base0D"; syntaxVariable = "base0C";
        syntaxString = "base0B"; syntaxNumber = "base0F";
        syntaxType = "base0A"; syntaxOperator = "base0C";
        syntaxPunctuation = "base05";
      };
    };
  };
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  config = lib.mkIf cfg.enable {
    home-manager.backupFileExtension = "backup";
    home-manager.sharedModules = builtins.attrValues self.homeModules ++ [
      inputs.mcp-servers-nix.homeManagerModules.default
    ];

    age.secrets = {
      mcp-better-email-password = { owner = lib.mkForce username; group = lib.mkForce "users"; };
      clarifai-pat = { owner = lib.mkForce username; };
      deepinfra-key = { owner = lib.mkForce username; };
      opencode-token = { owner = lib.mkForce username; };
      groq-token = { owner = lib.mkForce username; };
      github-token = { owner = lib.mkForce username; group = lib.mkForce "users"; };
    };

    users.users.${username}.isNormalUser = lib.mkDefault true;

    home-manager.users.${username} = lib.mkMerge [
      {
        home.stateVersion = lib.mkDefault "26.05";
        systemd.user.startServices = lib.mkDefault "sd-switch";
        imports = cfg.extraModules;
      }

      {
        my.programs = {
          bash.enable = lib.mkDefault true;
          zsh.enable = lib.mkDefault true;
          direnv.enable = lib.mkDefault true;
          ghostty.enable = lib.mkDefault true;
          just.enable = lib.mkDefault true;
          yazi.enable = lib.mkDefault true;
        };
      }

      {
        # Enable home-manager's centralized MCP server registry
        programs.mcp.enable = true;

        # Declare MCP servers via mcp-servers-nix — consumed by opencode,
        # claude-code, vscode, etc. via enableMcpIntegration.
        mcp-servers = {
          programs = {
            nixos.enable = true;
            fetch.enable = true;
            filesystem = {
              enable = true;
              args = [ "/home/seanc/nixos-config" ];
            };
            time.enable = true;
            sequential-thinking.enable = true;
            memory.enable = true;
            github = {
              enable = true;
              # Read token from agenix at runtime — never stored in /nix/store
              passwordCommand = {
                GITHUB_PERSONAL_ACCESS_TOKEN = [ "cat" "/run/agenix/github-token" ];
              };
            };
          };

          settings.servers = {
            # better-email with agenix secret read by wrapper
            better-email = {
              command = "${betterEmailPkg}/bin/better-email";
              env = {
                EMAIL_PROVIDER = "gmail";
                EMAIL_USER = flake.config.me.email;
              };
            };
          };
        };
      }

      {
        my.programs.opencode = {
          enable = lib.mkDefault true;
          enableLsp = lib.mkDefault true;
          clarifai.patFile = config.age.secrets.clarifai-pat.path;
          deepinfra.keyFile = config.age.secrets.deepinfra-key.path;
          opencode-go.keyFile = config.age.secrets.opencode-token.path;
          groq.keyFile = config.age.secrets.groq-token.path;

          model = lib.mkDefault null;
          enableMcpIntegration = lib.mkDefault true;

          # references are supported via my.programs.opencode.references but
          # require opencode ≥ 1.16 — not yet available in nixpkgs.

          plugins = lib.mkDefault [ "@hueyexe/opencode-ensemble@0.15.0" ];

          themes = opencodeTheme;
          tui.theme = "catppuccin-mocha";

          # Deny all providers except the ones we actually use
          policies = {
            enable = lib.mkDefault true;
            allowedProviders = lib.mkDefault [
              "opencode-go"
              "opencode-zen"
              "clarifai"
              "deepinfra"
            ];
          };

          # MCP server packages on PATH for manual use
          extraPackages = with pkgs; with mcpServersPkgs; [
            mcp-nixos
            mcp-server-fetch
            betterEmailPkg
            terraform
            nixpkgs-fmt
          ];
        };
      }

      cfg.extraConfig
    ];
  };
}
