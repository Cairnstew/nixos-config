{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.ssh-1password;

  agentSock =
    if pkgs.stdenv.isDarwin
    then "~/Library/Group\\ Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    else "~/.1password/agent.sock";
in
{
  options.my.programs.ssh-1password = {
    enable = lib.mkEnableOption "1Password SSH agent integration";

    install1PasswordCli = lib.mkOption {
      type    = lib.types.bool;
      default = true;
      description = "Install the 1Password CLI (op).";
    };

    additionalMatchBlocks = lib.mkOption {
      type    = lib.types.attrs;
      default = {};
      description = "Additional SSH match blocks to merge into my.services.ssh.matchBlocks.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = lib.mkIf cfg.install1PasswordCli [ pkgs._1password-cli ];

    my.services.ssh = {
      identityAgent = agentSock;
      matchBlocks   = cfg.additionalMatchBlocks;
    };
  };
}