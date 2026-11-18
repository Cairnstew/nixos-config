{ lib, ... }:

let
  inherit (lib) mkEnableOption mkOption types literalExpression;
in
{
  options.my.services.python-tofu = {
    enable = mkEnableOption "the python-tofu GCP infrastructure reconciler";

    stack = mkOption {
      type = types.nullOr (types.attrsOf types.anything);
      default = null;
      example = literalExpression ''
        {
          provider = {
            project = "my-project";
            region = "europe-west1";
          };
          buckets.artifacts = {
            project = "my-project";
            location = "EU";
          };
        }
      '';
      description = ''
        Cloud stack declared in Nix, using the upstream `nix/stack.nix`
        option tree. Sections are attr sets keyed by a local name and the key
        fills the resource identity field unless set explicitly
        (`buckets.artifacts` → `name = "artifacts"`).

        Evaluated at build time into JSON, so the unit needs neither network
        nor a `nix` binary at activation. Mutually exclusive with `stackFile`
        and with `services.python-tofu.settings.config`.
      '';
    };

    stackFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = literalExpression "./infra.nix";
      description = ''
        Nix module using the same option tree, for a declaration that needs
        `imports`/`mkMerge`/`mkIf`. Mutually exclusive with `stack`.
      '';
    };

    credentialsFile = mkOption {
      type = types.nullOr types.str;
      default = "/run/agenix/gcloud-auth";
      description = ''
        Path exported to the unit as `GOOGLE_APPLICATION_CREDENTIALS`.

        The default is this repo's agenix service-account key. An
        `/run/agenix/<name>` path is only exported when that secret is
        declared for the host (AGENTS.md §6.4), so hosts without it fall back
        to Application Default Credentials instead of failing to start.

        Set to `null` to export nothing and use ADC explicitly.
      '';
    };

    applyOnRebuild = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Reconcile the stack on activation: sets upstream
        `settings.command = "apply"` and `settings.autoApprove = true`. The
        upstream `restartTriggers` then re-run the unit on every rebuild that
        changes the evaluated stack or toolchain.

        Off by default — upstream's default command is `render`, which writes
        HCL without touching cloud state.
      '';
    };
  };
}
