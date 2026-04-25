{ config, flake, pkgs, lib, ... }:

let
  # ── Short aliases ───────────────────────────────────────
  me   = flake.config.me;
  user = me.username;
  self = flake.inputs.self;
in
{
  # ── SSH configuration ───────────────────────────────────
  nixos-unified.sshTarget = "seanc@server";

  # ── Imports ────────────────────────────────────────────
  imports = [
    ./configuration.nix
    self.nixosModules.default
  ];

  # ── Hardware configuration ─────────────────────────────
  hardwareProfiles.gpu.nvidia = {
    enable   = true;
    headless = true;
    open     = false;
    toolkit  = true;
    cuda     = true;
  };

  my.services.ollama = {
    enable = true;
    acceleration = "cuda";
    loadModels = [ "qwen2.5-coder:14b" "deepseek-r1:14b" "hf.co/Lewdiculous/DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small-GGUF-IQ-Imatrix"];
    models = "/mnt/data/models";
    host = "0.0.0.0";
  };

  my.services.sillytavern = {
    enable = true;
    port = 8111;
    listen = true;
    whitelistMode = true;
    whitelistAddresses = [ "100.111.231.84" ];

    ollama = {
      enable = true;
      host = "127.0.0.1";
      port = 11434;
      model = "hf.co/Lewdiculous/DS-R1-Qwen3-8B-ArliAI-RpR-v4-Small-GGUF-IQ-Imatrix";
    };

    presets.instruct = {
    
    };

    presets.context = {
      "hf.coLewdiculousDS-R1-Qwen3-8B-ArliAI-RpR-v4-Small-GGUF-IQ-Imatrixlatest" = {
        story_string = "{{#if anchorBefore}}{{anchorBefore}}\n{{/if}}{{#if system}}{{system}}\n{{/if}}{{#if wiBefore}}{{wiBefore}}\n{{/if}}{{#if description}}{{description}}\n{{/if}}{{#if personality}}{{personality}}\n{{/if}}{{#if scenario}}{{scenario}}\n{{/if}}{{#if wiAfter}}{{wiAfter}}\n{{/if}}{{#if persona}}{{persona}}\n{{/if}}{{#if anchorAfter}}{{anchorAfter}}\n{{/if}}{{trim}}";
        always_force_name2 = false;
      };
    };

    presets.sysprompt = {
      
    };

    presets.textgen = {
      # Sensible baseline — matches the Default.json you shared
      "Default" = { };

      # Good for creative/RP with your model
      "Creative" = {
        temp     = 1.1;
        top_p    = 0.95;
        min_p    = 0.05;
        rep_pen  = 1.05;
        genamt   = 2048;
      };
    };
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cuda.acceptLicense = true;
  
  # ── System settings ────────────────────────────────────
  my.system = {
    location = {
      enable    = true;
      timeZone  = "America/Chicago";
      latitude  = 30.2672;
      longitude = -97.7431;
    };
    battery = {
      enable = false;
    };
  };

  # ── System programs ────────────────────────────────────
  my.programs = {
    #spotify.enable = true;

  };

  # ── System tools ───────────────────────────────────────
  my.tools = {
    uup-converter.enable = false;
  };  

  # Virtualisation
  my.virtualisation = {
    waydroid = {
      enable = false;
    };
    docker = {
      enable = true;
      users = [ flake.config.me.username ];
      enableNvidiaContainerToolkit = true;
    };
  };

  # ── System services ────────────────────────────────────
  my.services = {
    #zerotier = {
    #  enable = true;
    #  allowDNS = false;
    #};
  };

  environment.systemPackages = [
    self.packages.${pkgs.stdenv.hostPlatform.system}.get-template
    pkgs.screen
    pkgs.terraform
  ];

  # ── Home Manager configuration ─────────────────────────
  home-manager.users.${user} = {
    imports = [
      "${flake.inputs.nixos-vscode-server}/modules/vscode-server/home.nix"
    ];
    
    my = {
      programs = {
      };
    };
    services.vscode-server.enable = true;
  };
}
