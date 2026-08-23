{ config, lib, pkgs, flake, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
  inherit (flake.config.me) username;
  cfg = config.my.homeManager;
  mcpServersPkgs = inputs.mcp-servers-nix.packages.${pkgs.system};

  # MCP wrapper packages + opencode theme live in ./mcp-wrappers.nix (recon M11).
  # Values are byte-identical to the block that previously lived here.
  mcpWrappers = import ./mcp-wrappers.nix {
    inherit config pkgs flake self;
  };
  inherit (mcpWrappers)
    betterEmailPkg
    googleCalendarMcpPkg
    secondhandMcpPkg
    shoppingscraperMcpPkg
    keepaMcpPkg
    opencodeTheme;
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  config = lib.mkIf cfg.enable {
    # The home-manager-seanc.service is Type=oneshot and runs `systemctl --user
    # show-environment` during activation. On the first rebuild after changes,
    # the user's systemd manager is often in transition (sysinit-reactivation.target
    # restarting, dbus-broker reloading), causing the command to fail. Auto-retry
    # makes it succeed on the next attempt after the session settles.
    systemd.services."home-manager-seanc" = {
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    home-manager.backupFileExtension = "backup";
    home-manager.sharedModules = builtins.attrValues self.homeModules ++ [
      inputs.mcp-servers-nix.homeManagerModules.default
    ];

    age.secrets = {
      mcp-better-email-password = { owner = lib.mkForce username; group = lib.mkForce "users"; };
      clarifai-pat = { owner = lib.mkForce username; };
      deepinfra-key = { owner = lib.mkForce username; };
      opencode-token = { owner = lib.mkForce username; };
      opencodeWeb-password = { owner = lib.mkForce username; group = lib.mkForce "users"; };
      groq-token = { owner = lib.mkForce username; };
      github-token = { owner = lib.mkForce username; group = lib.mkForce "users"; };
      spotify-cred = { owner = lib.mkForce username; };
      google-calendar-oauth = { owner = lib.mkForce username; group = lib.mkForce "users"; };
    };

    users.users.${username}.isNormalUser = lib.mkDefault true;

    home-manager.users.${username} = lib.mkMerge [
      {
        home.stateVersion = lib.mkDefault "26.05";
        systemd.user.startServices = lib.mkDefault "sd-switch";
        imports = cfg.extraModules;
      }

      # G8: my.programs defaults are declared once in profiles/home/config.nix
      # (common profile, imported via modules/nixos/profiles) — this duplicate
      # block removed (recon G8). Do not re-add bash/zsh/direnv/ghostty/just/yazi
      # mkDefault true here; keep single source of truth.

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
              args = [ "/home/${username}/nixos-config" ]; # use flake config username instead of hard-coded seanc (M2)
            };
            time.enable = true;
            sequential-thinking.enable = true;
            memory.enable = true;
            playwright.enable = true;
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
            # google-calendar-mcp — OAuth credentials from agenix
            google-calendar = {
              command = "${googleCalendarMcpPkg}/bin/google-calendar-mcp";
              env = {
                GOOGLE_OAUTH_CREDENTIALS = config.age.secrets.google-calendar-oauth.path;
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
          # CLI + 5-min cache refresher for OpenCode Go usage (dashboard feeds
          # off ~/.cache/opencode/go-usage.json). Guarded on the secret existing.
          opencode-go.usage.enable =
            lib.mkDefault (config.age.secrets ? "opencode-token");
          groq.keyFile = config.age.secrets.groq-token.path;

          model = lib.mkDefault "opencode-go/deepseek-v4-flash";
          enableMcpIntegration = lib.mkDefault true;

          # Shopping MCP servers. Each is enabled only when its agenix secret
          # exists (declared in secrets-manifest.json). Servers:
          #   - ebay  → secondhand-mcp (official Browse API, free dev keys)
          #   - amazon → ShoppingScraper API (paid SSC_API_KEY)
          #   - keepa → Amazon price history (paid KEEPA_API_KEY)
          # Create the secrets with: agenix-manager new
          mcp = lib.mkMerge [
            (lib.mkIf (config.age.secrets ? "ebay-client-id") {
              ebay = {
                enabled = true;
                type = "local";
                command = [ "${secondhandMcpPkg}/bin/secondhand-mcp" ];
                timeout = 120000;
              };
            })
            (lib.mkIf (config.age.secrets ? "ssc-api-key") {
              amazon = {
                enabled = true;
                type = "local";
                command = [ "${shoppingscraperMcpPkg}/bin/shoppingscraper-mcp" ];
                timeout = 120000;
              };
            })
            (lib.mkIf (config.age.secrets ? "keepa-api-key") {
              keepa = {
                enabled = true;
                type = "local";
                command = [ "${keepaMcpPkg}/bin/keepa-mcp" ];
                timeout = 120000;
              };
            })
          ];

          # references.sillytavern: enable when opencode supports the
          # references config key (open ≥ 1.16 / check release notes)
          # path = "/home/${username}/SillyTavern";

          plugins = lib.mkDefault [ "@hueyexe/opencode-ensemble@0.15.0" ];

          # Ensemble plugin config — agents use the paid OpenCode Go DeepSeek V4
          # Flash (opencode-go/ is the Go provider prefix; model id format per
          # https://opencode.ai/docs/go — "opencode-go/<model-id>"). Moved off the
          # free Zen tier (opencode-deepseek-v4-flash-free) to the normal flash for
          # better reliability/limits under the paid Go subscription.
          ensemble = lib.mkDefault {
            defaultModel = "opencode-go/deepseek-v4-flash";
            modelsByAgent = {
              build = "opencode-go/deepseek-v4-flash";
              explore = "opencode-go/deepseek-v4-flash";
              plan = "opencode-go/deepseek-v4-flash";
            };
            dashboardPort = 4747;
            mergeOnCleanup = true;
          };

          themes = opencodeTheme;
          tui.theme = lib.mkDefault "catppuccin-mocha";

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
            playwright-mcp
            betterEmailPkg
            googleCalendarMcpPkg
            terraform
            nixpkgs-fmt
          ];
        };
      }

      cfg.extraConfig
    ];
  };
}
