{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkMerge mkDefault;
  cfg = config.my.services.netboot;

  hasMachines = cfg.machines != { };

  # ── Packages ──
  autounattendBuilder = args: pkgs.callPackage ../../../packages/autounattend-xml args;
  netbootInstaller = pkgs.callPackage ./installer-builder.nix { };

  # Resolve effective password: passwordFile takes precedence
  resolvePassword = unattended:
    if unattended.passwordFile != null
    then builtins.readFile unattended.passwordFile
    else unattended.password;

  # Generate stage script content for a given machine + stage
  stageScript = name: machine: stage:
    let
      mac = machine.macAddress;
      server = cfg.serverAddress;
      winUnattended = machine.windows.unattended;
      nixAuto = machine.nixos.autoInstall;
    in
    {
      discover = if nixAuto.enable then ''
        #!ipxe
        echo "=== Stage: Discover (${name}) ==="
        echo "Booting interactive disk/hostname selector..."
        kernel http://${server}/machines/${mac}/vmlinuz pxe.server=${server} pxe.mac=${mac} pxe.stage=discover
        initrd http://${server}/machines/${mac}/initrd
        boot
      '' else ''
        #!ipxe
        echo "=== Stage: Discover (${name}) ==="
        echo "Skipping — autoInstall not enabled for this machine"
        shell
      '';
      windows =
        let
          autounattendInitrd = lib.optionalString winUnattended.enable ''
            initrd http://${server}/machines/${mac}/autounattend.xml  autounattend.xml
          '';
        in ''
          #!ipxe
          echo "=== Stage: Windows Installer (${name}) ==="
          kernel wimboot
          ${autounattendInitrd}initrd http://${server}/windows/boot/bcd         BCD
          initrd http://${server}/windows/boot/boot.sdi    boot.sdi
          initrd http://${server}/windows/sources/boot.wim boot.wim
          boot
        '';
      nixos = if nixAuto.enable then ''
        #!ipxe
        echo "=== Stage: NixOS Installer (${name}) ==="
        echo "Booting custom netboot installer..."
        kernel http://${server}/machines/${mac}/vmlinuz pxe.server=${server} pxe.mac=${mac}
        initrd http://${server}/machines/${mac}/initrd
        boot
      '' else ''
        #!ipxe
        echo "=== Stage: NixOS Installer (${name}) ==="
        echo "Chainloading ${cfg.nixos.label} netboot..."
        chain ${cfg.nixos.ipxeUrl} || echo "Failed to fetch NixOS netboot script"
        shell
      '';
      done = ''
        #!ipxe
        echo "=== Stage: Done (${name}) ==="
        echo "Installation sequence complete — booting from local disk"
        exit
      '';
    }.${stage};

  # Build per-machine artifacts at evaluation time
  machineArtifacts = lib.mapAttrs (name: machine:
    let
      mac = machine.macAddress;
      winUnattended = machine.windows.unattended;
      nixAuto = machine.nixos.autoInstall;

      # autounattend.xml derivation
      autounattend = lib.optionalAttrs winUnattended.enable {
        autounattend-xml = autounattendBuilder {
          windowsPartitionIndex = 2;
          localPassword = resolvePassword winUnattended;
          localUsername = winUnattended.localUser;
          timeZone = winUnattended.timeZone;
          windowsEdition = winUnattended.edition;
          computerName = winUnattended.computerName;
          disableRecoveryPartition = winUnattended.disableRecovery;
        };
      };

      # Install bundle for autoInstall
      installBundle = lib.optionalAttrs nixAuto.enable (
        let
          diskoJson = pkgs.writeText "disko.json" (builtins.toJSON nixAuto.diskoConfig);
          diskoFile = pkgs.writeText "disko.nix" ''
            { lib, config, ... }:
            builtins.fromJSON (builtins.readFile ./disko.json)
          '';
          nixosConfigFile = pkgs.writeText "configuration.nix" nixAuto.nixosConfig;
        in
        {
          install-bundle = pkgs.runCommandLocal "install-bundle" { } ''
            mkdir -p $out
            cp ${diskoFile} $out/disko.nix
            cp ${diskoJson} $out/disko.json
            cp ${nixosConfigFile} $out/configuration.nix
            tar czf $out/bundle.tar.gz -C $out . --transform 's|^\./||'
          '';
        }
      );
    in
    autounattend // installBundle
  ) cfg.machines;

  # Derivation containing all generated boot content
  netbootContent = pkgs.runCommandLocal "netboot-content" { } (
    let
      stageFiles = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: machine:
        let
          mac = machine.macAddress;
          firstStage = builtins.head machine.stages;
        in
        ''
          mkdir -p "$out/stages/${mac}"
          ${lib.concatStringsSep "\n" (map (s: ''
            cat > "$out/stages/${mac}/stage-${s}.ipxe" << 'EOF_STAGE'
        ${stageScript name machine s}
        EOF_STAGE
          '') machine.stages)}
          ln -sf "stage-${firstStage}.ipxe" "$out/${mac}.ipxe"
        ''
      ) cfg.machines);

      machineDirEntries = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: machine:
        let
          mac = machine.macAddress;
          artifacts = machineArtifacts.${name};
        in
        ''
          mkdir -p "$out/machines/${mac}"
          ${lib.optionalString (artifacts ? autounattend-xml) ''
            cp "${artifacts.autounattend-xml}/autounattend.xml" "$out/machines/${mac}/autounattend.xml"
          ''}
          ${lib.optionalString (artifacts ? install-bundle) ''
            cp "${artifacts.install-bundle}/bundle.tar.gz" "$out/machines/${mac}/config.tar.gz"
            ln -sf "${netbootInstaller.kernel}" "$out/machines/${mac}/vmlinuz"
            ln -sf "${netbootInstaller.netbootRamdisk}" "$out/machines/${mac}/initrd"
          ''}
        ''
      ) cfg.machines);

      bootIpxe = if hasMachines then
        lib.concatStringsSep "\n" (lib.mapAttrsToList (name: machine: ''
          :${machine.macAddress}
          chain http://${cfg.serverAddress}/${machine.macAddress}.ipxe || goto next
        '') cfg.machines)
      else ''
        echo "No netboot machines configured in my.services.netboot.machines"
        shell
      '';
    in
    ''
      mkdir -p "$out"
      ${stageFiles}
      ${machineDirEntries}
      cat > "$out/boot.ipxe" << 'EOF_MAIN'
    #!ipxe
    echo "=== NixOS Netboot Server ==="
    ${bootIpxe}
    :next
    echo "No matching machine config — booting local disk"
    exit
    EOF_MAIN
    ''
  );

in
{
  config = mkIf cfg.enable (mkMerge [
    # ── Network ──
    {
      networking.interfaces.${cfg.interface}.ipv4.addresses = [{
        address = cfg.serverAddress;
        prefixLength = cfg.subnetPrefix;
      }];
    }

    # ── DHCP + TFTP (dnsmasq) — daemon mode only ──
    (mkIf (cfg.serveMode == "daemon") {
      services.dnsmasq = {
        enable = true;
        settings = {
          interface = cfg.interface;
          bind-interfaces = true;
          dhcp-range = "${cfg.dhcpRange},${cfg.dhcpLeaseTime}";
          enable-tftp = true;
          tftp-root = cfg.tftpRoot;
          "dhcp-boot" = [
            "undionly.kpxe"
            "tag:efi-x86_64,ipxe.efi"
            "tag:ipxe,http://${cfg.serverAddress}/boot.ipxe"
          ];
          "dhcp-match" = [
            "set:efi-x86_64,option:client-arch,7"
            "set:ipxe,175"
          ];
        };
      };
    })

    # ── HTTP (nginx) — daemon mode only ──
    (mkIf (cfg.serveMode == "daemon") {
      services.nginx = {
        enable = true;
        virtualHosts."netboot" = {
          listen = [{ addr = cfg.serverAddress; port = 80; }];
          root = cfg.httpRoot;
          extraConfig = "autoindex on;";
        };
      };
    })

    # ── Firewall — daemon mode only ──
    (mkIf (cfg.serveMode == "daemon") {
      networking.firewall = {
        allowedUDPPorts = [ 67 69 ];
        allowedTCPPorts = [ 69 80 ];
      };
    })

    # ── Directories and binaries ──
    {
      systemd.tmpfiles.settings."10-netboot" = {
        "${cfg.tftpRoot}".d = {
          mode = "0755";
          user = "root";
          group = "root";
        };
        "${cfg.httpRoot}".d = {
          mode = "0755";
          user = "root";
          group = "root";
        };
        "${cfg.tftpRoot}/undionly.kpxe".L = {
          argument = "${pkgs.ipxe}/share/ipxe/undionly.kpxe";
        };
        "${cfg.tftpRoot}/ipxe.efi".L = {
          argument = "${pkgs.ipxe}/share/ipxe/ipxe.efi";
        };
        "${cfg.httpRoot}/boot.ipxe".L = {
          argument = "${netbootContent}/boot.ipxe";
        };
      };
    }

    # ── Stage scripts (read-only, from Nix store) ──
    (mkIf hasMachines {
      systemd.tmpfiles.settings."10-netboot" = {
        "${cfg.httpRoot}/stages".L = {
          argument = "${netbootContent}/stages";
        };
      };
    })

    # ── Machine artifacts (writable directory + per-file symlinks) ──
    (mkIf hasMachines {
      systemd.tmpfiles.settings."10-netboot" =
        let
          machineDir = name: mac: {
            "${cfg.httpRoot}/machines/${mac}".d = {
              mode = "0755";
              user = "root";
              group = "root";
            };
          };
          autounattendLink = name: mac: artifacts: lib.optionalAttrs (artifacts ? autounattend-xml) {
            "${cfg.httpRoot}/machines/${mac}/autounattend.xml".L = {
              argument = "${artifacts.autounattend-xml}/autounattend.xml";
            };
          };
          vmlinuzLink = name: mac: artifacts: lib.optionalAttrs (artifacts ? install-bundle) {
            "${cfg.httpRoot}/machines/${mac}/vmlinuz".L = {
              argument = "${netbootInstaller.kernel}";
            };
            "${cfg.httpRoot}/machines/${mac}/initrd".L = {
              argument = "${netbootInstaller.netbootRamdisk}";
            };
            # Only symlink config bundle if discover stage is NOT in the list
            # (discover uses the webhook to generate it at runtime)
            "${cfg.httpRoot}/machines/${mac}/config.tar.gz".L = lib.mkIf (!builtins.elem "discover" cfg.machines.${name}.stages) {
              argument = "${artifacts.install-bundle}/bundle.tar.gz";
            };
          };
        in
        lib.mkMerge (
          lib.flatten (lib.mapAttrsToList (name: machine:
            let
              mac = machine.macAddress;
              artifacts = machineArtifacts.${name};
            in
            [
              (machineDir name mac)
              (autounattendLink name mac artifacts)
              (vmlinuzLink name mac artifacts)
            ]
          ) cfg.machines)
        );
    })

    # ── Windows boot files ──
    (mkIf cfg.windows.enable {
      systemd.tmpfiles.settings."10-netboot" = {
        "${cfg.windows.bootDir}".d = {
          mode = "0755";
          user = "root";
          group = "root";
        };
      };
    })
  ]);
}
