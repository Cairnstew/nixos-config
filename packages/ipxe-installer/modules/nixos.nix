# ipxe-installer — NixOS module
# Python CLI handles runtime (DHCP, TFTP, HTTP, stages, artifacts).
# This module provides: firewall rules, tmpfiles, systemd services, package install.
{ lib, config, pkgs, ... }:

let
  cfg = config.my.services.ipxeInstaller;
  pkg = pkgs.callPackage ../default.nix { };
  inherit (lib) mkIf mkOption mkEnableOption types;
in
{
  options.my.services.ipxeInstaller = {
    enable = mkEnableOption "iPXE netboot installer server";
    interface = mkOption { type = types.str; default = ""; };
    serverAddress = mkOption { type = types.str; default = "192.168.99.1"; };
    subnetPrefix = mkOption { type = types.ints.between 8 30; default = 24; };
    dhcpRange = mkOption { type = types.str; default = "192.168.99.100,192.168.99.200,1d"; };
    httpRoot = mkOption { type = types.path; default = "/srv/pxe"; };
    tftpRoot = mkOption { type = types.path; default = "/srv/tftp"; };

    serveMode = mkOption {
      type = types.enum [ "cli" "daemon" ];
      default = "cli";
    };

    profiles = mkOption {
      type = types.attrsOf (types.submodule ({ lib, ... }: {
        options = {
          description = mkOption { type = types.str; default = ""; };
          stages = mkOption { type = types.listOf types.str; default = [ "nixos" "windows" "done" ]; };
          dscConfig = mkOption { type = types.attrs; default = { }; };
          windows.unattended = {
            enable = mkOption { type = types.bool; default = false; };
            partitionIndex = mkOption { type = types.int; default = 3; };
            localUser = mkOption { type = types.str; default = "nixos"; };
            password = mkOption { type = types.str; default = "nixos123"; };
            computerName = mkOption { type = types.str; default = "DESKTOP"; };
          };
          nixos.autoInstall = {
            enable = mkOption { type = types.bool; default = false; };
            diskoConfig = mkOption { type = types.attrs; default = { }; };
            nixosConfig = mkOption { type = types.str; default = ""; };
          };
        };
      }));
      default = { };
    };

    machines = mkOption {
      type = types.attrsOf (types.submodule ({ lib, ... }: {
        options = {
          macAddress = mkOption { type = types.str; };
          stages = mkOption { type = types.listOf types.str; default = [ ]; };
          windows.unattended = {
            enable = mkOption { type = types.bool; default = false; };
            partitionIndex = mkOption { type = types.int; default = 3; };
            localUser = mkOption { type = types.str; default = "nixos"; };
            password = mkOption { type = types.str; default = "nixos123"; };
            computerName = mkOption { type = types.str; default = "DESKTOP"; };
          };
          dscConfig = mkOption { type = types.attrs; default = { }; };
        };
      }));
      default = { };
    };

    windows = {
      enable = mkOption { type = types.bool; default = false; };
      bootDir = mkOption { type = types.path; default = "${cfg.httpRoot}/windows"; };
    };

    nixos = {
      enable = mkOption { type = types.bool; default = false; };
      ipxeUrl = mkOption {
        type = types.str;
        default = "https://github.com/nix-community/nixos-images/releases/download/nixos-unstable/netboot-x86_64-linux.ipxe";
      };
    };

    # Netboot installer builder reference
    installerBuilder = mkOption {
      type = types.package;
      description = "NixOS netboot installer (kernel + initrd) derivation";
      default = pkgs.callPackage ./builder.nix { };
    };

    # Profile artifact exporting
    profileArtifacts = mkOption {
      type = types.attrsOf types.package;
      description = "Profile artifacts (build-time generated files)";
      internal = true;
    };
  };

  # ── Config ──

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkg ];

    # Tmpfiles for server directories
    systemd.tmpfiles.settings."10-ipxe-installer" = {
      "${cfg.httpRoot}/machines".d = { mode = "0755"; user = "root"; group = "root"; };
      "${cfg.httpRoot}/stages".d = { mode = "0755"; user = "root"; group = "root"; };
      "${cfg.httpRoot}/profiles".d = { mode = "0755"; user = "root"; group = "root"; };
      "${cfg.tftpRoot}".d = { mode = "0755"; user = "root"; group = "root"; };
    } // lib.optionalAttrs cfg.windows.enable {
      "${cfg.windows.bootDir}".d = { mode = "0755"; user = "root"; group = "root"; };
    };

    # Profile outputs — each profile gets a directory with profile.json + artifacts
    systemd.tmpfiles.settings."10-ipxe-installer-profiles" =
      let
        profileDir = name: dir: {
          "${cfg.httpRoot}/profiles/${name}".L = { argument = "${dir}"; };
        };
      in
      lib.mkMerge (lib.mapAttrsToList profileDir cfg.profileArtifacts);

    # Firewall (daemon mode)
    networking.firewall = mkIf (cfg.serveMode == "daemon") {
      allowedUDPPorts = [ 67 69 ];
      allowedTCPPorts = [ 69 80 8888 ];
    };

    # Daemon mode systemd service
    systemd.services.ipxe-installer = mkIf (cfg.serveMode == "daemon") {
      description = "iPXE Netboot Installer Server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkg}/bin/ipxe-installer serve --interface ${cfg.interface} --address ${cfg.serverAddress} --daemon";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    # Webhook socket (discover stage, daemon mode)
    systemd.sockets.netboot-webhook = mkIf (cfg.serveMode == "daemon") {
      description = "Netboot discover webhook socket";
      listenStreams = [ "${cfg.serverAddress}:8888" ];
      socketConfig.Accept = true;
      wantedBy = [ "sockets.target" ];
    };

    systemd.services.netboot-webhook = mkIf (cfg.serveMode == "daemon") {
      description = "Netboot discover webhook handler";
      requires = [ "netboot-webhook.socket" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.writeShellScript "netboot-webhook" ''
          read -r body
          echo "$body" | ${pkg}/bin/ipxe-installer webhook
        ''}";
        StandardInput = "socket";
      };
    };

    # Windows ISO sync
    systemd.services.windows-iso-sync = mkIf cfg.windows.enable {
      description = "Windows ISO Sync";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = with pkgs; [ pkg p7zip curl ];
      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "windows-iso-sync";
        ExecStart = "${pkg}/bin/ipxe-installer sync-iso --output ${cfg.windows.bootDir}";
      };
    };

    systemd.timers.windows-iso-sync = mkIf cfg.windows.enable {
      description = "Windows ISO Sync timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
      };
    };
  };
}
