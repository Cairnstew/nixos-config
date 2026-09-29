{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.mailFilter;
in
{
  config = lib.mkIf cfg.enable {
    # Pigeonhole 0.5 (Dovecot 2.3 pair): classic config syntax that sovereign
    # tools parse reliably. The 2.4 pigeonhole in nixpkgs fails `sievec -c`
    # config parsing (sieve settings struct not registered for CLI tools).
    home.packages = [ pkgs.isync pkgs.dovecot_pigeonhole_0_5 ];

    # programs.mbsync.enable generates ~/.config/isyncrc from the account below.
    programs.mbsync.enable = true;

    accounts.email = {
      # accounts.email.<name>.maildir is now { path } relative to this base.
      # maildirBasePath applies home-directory prefixing to non-absolute values,
      # so pass an absolute base here (default cfg.maildir = ~/.mail/gmail).
      maildirBasePath =
        let
          base = lib.dirOf cfg.maildir;
        in
        if lib.hasPrefix "/" base then base else "${config.home.homeDirectory}${lib.removePrefix "~" base}";
      accounts.${cfg.account} = {
        primary = true;
        inherit (cfg) address userName passwordCommand;

        imap = {
          host = cfg.imap.host;
          port = cfg.imap.port;
          tls.enable = true;
        };

        maildir.path = lib.baseNameOf cfg.maildir;

        mbsync = {
          enable = true;
          create = "both";
          expunge = "both";
          subFolders = "Verbatim";
          patterns = cfg.sync.patterns;
          extraConfig = {
            channel = {
              SyncState = "*";
            };
            # Dovecot layout=fs treats the maildir ROOT as INBOX; mbsync defaults
            # INBOX to <maildir>/INBOX. Override so both sides agree on the root
            # (cur/new/tmp at the root, label folders as subdirs).
            local = {
              Inbox = "${cfg.maildir}/";
            };
          };
        };
      };
    };

    # HM writes the generated isyncrc to ~/.config/isyncrc (XDG) — services.mbsync
    # defaults to ~/.mbsyncrc, so point it at the generated file explicitly.
    services.mbsync = {
      enable = true;
      frequency = cfg.sync.frequency;
      configFile = "${config.home.homeDirectory}/.config/isyncrc";
    };
  };
}