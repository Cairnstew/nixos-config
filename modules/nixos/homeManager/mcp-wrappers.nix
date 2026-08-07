# Sidecar: self-contained MCP wrapper packages + opencode theme.
#
# Split out of config.nix (recon M11 / task T9) so the homeManager module keeps
# only the wiring/glue; these wrapper package definitions are pure and reusable.
# Every value here is byte-identical to what config.nix previously defined in its
# top `let` block. The only outer-scope bindings these definitions depend on are
# passed in as function args:
#   - pkgs   (writeShellApplication, nodejs)
#   - config (agenix secret paths read at runtime)
#   - self   (keepa-mcp package shipped by this flake)
#   - flake  (me.colorScheme used to derive the opencode theme)
{ config, pkgs, flake, self }:
{
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

  googleCalendarMcpPkg =
    pkgs.writeShellApplication {
      name = "google-calendar-mcp";
      runtimeInputs = [ pkgs.nodejs ];
      text = ''
        exec npx -y @cocal/google-calendar-mcp "$@"
      '';
      meta.description = "MCP server: Google Calendar integration";
    };

  # eBay search + listing details (official Browse API). Keys come from agenix.
  # Covers Facebook Marketplace too; Depop/Poshmark need Chrome, so they're off.
  # If either key file is missing or empty at runtime, exit non-zero so opencode
  # marks the server failed instead of exposing broken tools.
  secondhandMcpPkg =
    pkgs.writeShellApplication {
      name = "secondhand-mcp";
      runtimeInputs = [ pkgs.nodejs ];
      text = ''
        if [[ ! -s ${config.age.secrets.ebay-client-id.path} || ! -s ${config.age.secrets.ebay-client-secret.path} ]]; then
          echo "secondhand-mcp disabled: ebay-client-id or ebay-client-secret is missing/empty" >&2
          exit 1
        fi
        export EBAY_CLIENT_ID="$(cat ${config.age.secrets.ebay-client-id.path})"
        export EBAY_CLIENT_SECRET="$(cat ${config.age.secrets.ebay-client-secret.path})"
        export MARKETPLACES="ebay,facebook"
        exec npx -y secondhand-mcp "$@"
      '';
      meta.description = "MCP server: eBay/Facebook Marketplace search (official Browse API)";
    };

  # Amazon offers/buybox/info/reviews via ShoppingScraper API (paid key).
  shoppingscraperMcpPkg =
    pkgs.writeShellApplication {
      name = "shoppingscraper-mcp";
      runtimeInputs = [ pkgs.nodejs ];
      text = ''
        if [[ ! -s ${config.age.secrets.ssc-api-key.path} ]]; then
          echo "shoppingscraper-mcp disabled: ssc-api-key is missing/empty" >&2
          exit 1
        fi
        export SSC_API_KEY="$(cat ${config.age.secrets.ssc-api-key.path})"
        exec npx -y @shoppingscraper/cli mcp serve "$@"
      '';
      meta.description = "MCP server: Amazon offers, buybox, info, reviews (ShoppingScraper API)";
    };

  # Amazon price history via Keepa API (paid key).
  keepaMcpPkg =
    pkgs.writeShellApplication {
      name = "keepa-mcp";
      runtimeInputs = [ pkgs.nodejs ];
      text = ''
        if [[ ! -s ${config.age.secrets.keepa-api-key.path} ]]; then
          echo "keepa-mcp disabled: keepa-api-key is missing/empty" >&2
          exit 1
        fi
        export KEEPA_API_KEY="$(cat ${config.age.secrets.keepa-api-key.path})"
        exec ${self.packages.${pkgs.system}.keepa-mcp}/bin/keepa-mcp "$@"
      '';
      meta.description = "MCP server: Keepa Amazon price history, deals, sellers";
    };

  # Opencode theme derived from config.nix me.colorScheme
  # Maps semantic UI roles to Base16 color definitions
  opencodeTheme =
    let
      c = flake.config.me.colorScheme;
    in
    {
      catppuccin-mocha = {
        defs = {
          inherit (c) base00 base01 base02 base03 base04 base05 base06 base07
            base08 base09 base0A base0B base0C base0D base0E base0F
            cursor;
        };
        theme = {
          primary = "base0D";
          secondary = "base0C";
          accent = "base0E";
          error = "base08";
          warning = "base09";
          success = "base0B";
          info = "base0D";
          text = "base05";
          textMuted = "base04";
          background = "base00";
          backgroundPanel = "base01";
          backgroundElement = "base02";
          border = "base03";
          borderActive = "base0D";
          borderSubtle = "base02";
          diffAdded = "base0B";
          diffRemoved = "base08";
          diffContext = "base03";
          diffHunkHeader = "base04";
          diffHighlightAdded = "base0B";
          diffHighlightRemoved = "base08";
          diffAddedBg = "base02";
          diffRemovedBg = "base02";
          diffContextBg = "base01";
          diffLineNumber = "base03";
          diffAddedLineNumberBg = "base01";
          diffRemovedLineNumberBg = "base01";
          markdownText = "base05";
          markdownHeading = "base0D";
          markdownLink = "base0C";
          markdownLinkText = "base0D";
          markdownCode = "base0B";
          markdownBlockQuote = "base03";
          markdownEmph = "base09";
          markdownStrong = "base0A";
          markdownHorizontalRule = "base03";
          markdownListItem = "base0D";
          markdownListEnumeration = "base0C";
          markdownImage = "base0C";
          markdownImageText = "base0E";
          markdownCodeBlock = "base05";
          syntaxComment = "base03";
          syntaxKeyword = "base0E";
          syntaxFunction = "base0D";
          syntaxVariable = "base0C";
          syntaxString = "base0B";
          syntaxNumber = "base0F";
          syntaxType = "base0A";
          syntaxOperator = "base0C";
          syntaxPunctuation = "base05";
        };
      };
    };
}
