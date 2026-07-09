# modules/nixos/profiles/system/ai.nix
# AI frontend services profile — enables all AI/LLM frontends with sensible defaults
# connecting to the local Ollama instance via the shared Docker network.
{ config, lib, flake, ... }:
let
  cfg = config.my.profiles.ai;
in
{
  config = lib.mkIf cfg.enable {
    # ── RisuAI: LLM roleplay frontend with HypaMemory/SupaMemory ──────────────
    # mkDefault: Enables the OCI container on port 6001, connected to Ollama
    # Override when: Not using or want different port/custom API endpoint
    my.services.risuai = {
      enable = lib.mkDefault true;
      ollama.enable = lib.mkDefault true;
      port = lib.mkDefault 6001;
    };

    # ── Open WebUI: Full-featured AI platform with MCP, RAG, memory ──────────
    # mkDefault: Enables the OCI container on port 3000, connected to Ollama
    # Override when: Prefer different port or no web search
    my.services.open-webui = {
      enable = lib.mkDefault true;
      port = lib.mkDefault 3000;
      ollama.enable = lib.mkDefault true;
    };

    # ── Letta: Stateful AI memory platform (formerly MemGPT) ─────────────────
    # mkDefault: Enables the OCI container on port 8283 with Ollama backend
    # Override when: Not using or need PostgreSQL instead of SQLite
    my.services.letta = {
      enable = lib.mkDefault true;
      port = lib.mkDefault 8283;
      ollama = {
        enable = lib.mkDefault true;
        defaultModel = lib.mkDefault "llama3.2:3b";
      };
    };

    # ── Jan: Desktop ChatGPT alternative (enabled only on desktop hosts) ─────
    # mkDefault false on servers (no GUI), mkDefault true on workstations
    # Override: Enable explicitly on desktop with `my.services.jan.apiServer.enable`
    my.services.jan.enable = lib.mkDefault false;

    # ── Assertions ──────────────────────────────────────────────────────────
    assertions = [
      {
        assertion = cfg.enable -> config.my.services.ollama.enable;
        message = ''
          my.profiles.ai requires Ollama to be enabled.
          Add `my.services.ollama.enable = true;` or use a profile that enables it.
          The AI frontends (RisuAI, Open WebUI, Letta) all connect to Ollama
          as their LLM backend.
        '';
      }
    ];
  };
}
