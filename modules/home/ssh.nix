{ pkgs, config, lib, flake, ... }:

let
  cfg = config.my.services.ssh;
in
{
  options.my.services.ssh = {
    enable = lib.mkEnableOption "SSH configuration";

    keyType = lib.mkOption {
      type = lib.types.enum [ "ed25519" "rsa" "ecdsa" ];
      default = "ed25519";
      description = "SSH key type to generate.";
    };

    keyPath = lib.mkOption {
      type = lib.types.str;
      default = "~/.ssh/id_ed25519";
      description = "Path to the SSH key file.";
    };

    email = lib.mkOption {
      type = lib.types.str;
      default = flake.config.me.email;
      description = "Email address to use as the SSH key comment.";
    };

    addKeysToAgent = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to automatically add keys to the SSH agent.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Additional SSH client configuration.";
    };

    generateKey = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to auto-generate an SSH key on activation if one doesn't exist.";
    };

    enableAgent = lib.mkOption {
      type = lib.types.bool;
      default = pkgs.stdenv.isLinux;
      description = "Whether to enable the SSH agent service (Linux only).";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      extraConfig = lib.concatStringsSep "\n" (
        lib.optional cfg.addKeysToAgent "AddKeysToAgent yes"
        ++ lib.optional (cfg.extraConfig != "") cfg.extraConfig
      );
    };

    home.activation.generateSSHKey = lib.mkIf cfg.generateKey (
      config.lib.dag.entryAfter [ "writeBoundary" ] ''
        if [ ! -f ${cfg.keyPath} ]; then
          mkdir -p $(dirname ${cfg.keyPath})
          ${pkgs.openssh}/bin/ssh-keygen -t ${cfg.keyType} -C "${cfg.email}" -f ${cfg.keyPath} -N ""
          echo "Generated new SSH key (${cfg.keyType}) for ${cfg.email}"
        fi
      ''
    );

    services.ssh-agent = lib.mkIf cfg.enableAgent { enable = true; };
  };
}