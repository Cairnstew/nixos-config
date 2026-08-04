{ config, lib, ... }:

let
  cfg = config.my.services.opencodeWeb;
  syncRepos = config.my.services.gitRepoSync.repos or { };
  missingRepos = builtins.filter (r: !(syncRepos ? ${r})) cfg.repos;
  orphanInstances = builtins.filter (name: !(builtins.elem name cfg.repos)) (builtins.attrNames cfg.instances);
in
{
  # ── L0: Nix assertions ────────────────────────────────────────────────────
  assertions = [
    {
      assertion = !cfg.enable || cfg.user != null;
      message = "my.services.opencodeWeb.user must be set (e.g. the primary user) when opencodeWeb is enabled.";
    }
    {
      assertion = missingRepos == [ ];
      message = "my.services.opencodeWeb.repos references repositories not declared in "
        + "my.services.gitRepoSync.repos: ${builtins.concatStringsSep ", " missingRepos}. "
        + "Add them to my.services.gitRepoSync.repos so the checkout path can be resolved "
        + "(the opencode module is intentionally bridged to gitreposync).";
    }
    {
      assertion = orphanInstances == [ ];
      message = "my.services.opencodeWeb.instances keys must be listed in my.services.opencodeWeb.repos: "
        + "${builtins.concatStringsSep ", " orphanInstances}.";
    }
    {
      assertion = !cfg.enable || cfg.repos != [ ];
      message = "my.services.opencodeWeb.repos must not be empty when opencodeWeb is enabled.";
    }
  ];

  # ── Diagnostic warnings ──────────────────────────────────────────────────
  # Exposing opencode on the tailnet without basic auth means any tailnet node
  # can use your API keys; recommend a password for defense in depth.
  warnings = lib.optional (cfg.enable && cfg.tailnetServe.enable && cfg.passwordFile == null)
    ("my.services.opencodeWeb is exposed on the tailnet (tailnetServe.enable = true) without a passwordFile. "
      + "Consider setting my.services.opencodeWeb.passwordFile so the server requires basic auth.");
}
