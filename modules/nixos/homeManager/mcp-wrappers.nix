# Sidecar: self-contained MCP wrapper packages.
#
# Split out of config.nix (recon M11 / task T9) so the homeManager module keeps
# only the wiring/glue; these wrapper package definitions are pure and reusable.
# Every value here is byte-identical to what config.nix previously defined in its
# top `let` block. The only outer-scope bindings these definitions depend on are
# passed in as function args:
#   - pkgs   (writeShellApplication, nodejs)
#   - config (agenix secret paths read at runtime)
#   - self   (keepa-mcp package shipped by this flake)
{ config, pkgs, self }:
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
        exec ${self.packages.${pkgs.stdenv.hostPlatform.system}.keepa-mcp}/bin/keepa-mcp "$@"
      '';
      meta.description = "MCP server: Keepa Amazon price history, deals, sellers";
    };

  # Official GitHub MCP server (github/github-mcp-server, Go binary).
  # Reads the PAT from agenix at runtime so it never appears in /nix/store.
  githubMcpPkg =
    pkgs.writeShellApplication {
      name = "github-mcp-server";
      runtimeInputs = [ pkgs.github-mcp-server ];
      text = ''
        if [[ ! -s ${config.age.secrets.github-token.path} ]]; then
          echo "github-mcp-server disabled: github-token is missing/empty" >&2
          exit 1
        fi
        GITHUB_PERSONAL_ACCESS_TOKEN="$(cat ${config.age.secrets.github-token.path})"
        export GITHUB_PERSONAL_ACCESS_TOKEN
        export GITHUB_TOOLSETS="repos,issues,pull_requests,actions,code_security,context"
        exec github-mcp-server stdio "$@"
      '';
      meta.description = "MCP server: GitHub official (repos, issues, PRs, actions, file tree)";
    };
}
