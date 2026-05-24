{ lib, cfg, ... }:

let
  inherit (lib)
    optionalAttrs
    filterAttrs
    mapAttrs
    attrNames
    findFirst
    mkDefault
    foldl'
    recursiveUpdate
    ;

  # ── Ollama provider ───────────────────────────────────────────────────────
  ollamaProviderSettings = optionalAttrs (cfg.ollamaModels != { }) {
    provider.ollama = {
      npm = "@ai-sdk/openai-compatible";
      name = "Ollama (local)";
      options.baseURL = cfg.ollamaBaseURL;
      models = mapAttrs
        (tag: mcfg:
          let
            modelOpts = filterAttrs (_: v: v != null) {
              num_ctx = mcfg.numCtx        or null;
              temperature = mcfg.temperature   or null;
              top_p = mcfg.topP          or null;
              top_k = mcfg.topK          or null;
              repeat_penalty = mcfg.repeatPenalty or null;
              num_predict = mcfg.numPredict    or null;
              seed = mcfg.seed          or null;
            };
          in
          { name = mcfg.name or tag; tools = mcfg.tools or false; }
          // optionalAttrs (modelOpts != { }) { options = modelOpts; }
        )
        cfg.ollamaModels;
    };
  };

  defaultOllamaModel = findFirst
    (tag: (cfg.ollamaModels.${tag}.opencode_default or false) == true)
    null
    (attrNames cfg.ollamaModels);

  # ── SDK-based providers (env-var keys) ──────────────────────────────────
  mkSdkProvider = name: npm: envVar: keyFile:
    optionalAttrs (keyFile != null) {
      provider.${name} = {
        inherit npm;
        name = lib.toUpper name;
      };
    };

  openaiProviderSettings = mkSdkProvider "openai" "@ai-sdk/openai" "OPENAI_API_KEY" cfg.openai.keyFile;
  anthropicProviderSettings = mkSdkProvider "anthropic" "@ai-sdk/anthropic" "ANTHROPIC_API_KEY" cfg.anthropic.keyFile;
  googleProviderSettings = mkSdkProvider "google" "@ai-sdk/google" "GOOGLE_GENERATIVE_AI_API_KEY" cfg.google.keyFile;
  groqProviderSettings = mkSdkProvider "groq" "@ai-sdk/groq" "GROQ_API_KEY" cfg.groq.keyFile;
  mistralProviderSettings = mkSdkProvider "mistral" "@ai-sdk/mistral" "MISTRAL_API_KEY" cfg.mistral.keyFile;
  xaiProviderSettings = mkSdkProvider "xai" "@ai-sdk/xai" "XAI_API_KEY" cfg.xai.keyFile;

  # ── OpenAI-compatible providers (file-substitution keys) ─────────────────
  # Uses {file:...} substitution because opencode has a known bug where
  # {env:...} does not expand for apiKey in openai-compatible providers.
  mkOpenAiProvider = name: baseURL: keyFile:
    optionalAttrs (keyFile != null) {
      provider.${name} = {
        npm = "@ai-sdk/openai-compatible";
        name = lib.toUpper name;
        options.baseURL = baseURL;
        options.apiKey = "{file:${keyFile}}";
      };
    };

  togetherProviderSettings = mkOpenAiProvider "together" "https://api.together.xyz/v1" cfg.together.keyFile;
  openrouterProviderSettings = mkOpenAiProvider "openrouter" "https://openrouter.ai/api/v1" cfg.openrouter.keyFile;
  fireworksProviderSettings = mkOpenAiProvider "fireworks" "https://api.fireworks.ai/inference/v1" cfg.fireworks.keyFile;
  cerebrasProviderSettings = mkOpenAiProvider "cerebras" "https://api.cerebras.ai/v1" cfg.cerebras.keyFile;
  clarifaiProviderSettings = mkOpenAiProvider "clarifai" "https://api.clarifai.com/v2/ext/openai/v1" cfg.clarifai.patFile;
  # Note: opencode-go is a first-class provider and must NOT be in the provider block
  # Its credentials are written to auth.json via home.activation

  # ── Azure OpenAI ────────────────────────────────────────────────────────
  azureProviderSettings = optionalAttrs
    (cfg.azure.keyFile != null && cfg.azure.endpoint != null && cfg.azure.deployment != null)
    {
      provider.azure = {
        npm = "@ai-sdk/azure";
        name = "Azure OpenAI";
        options.baseURL = cfg.azure.endpoint;
        options.apiKey = "{file:${cfg.azure.keyFile}}";
        options.deployment = cfg.azure.deployment;
      };
    };

  # ── Merge all provider settings ─────────────────────────────────────────
  allProviderSettings = lib.foldl' lib.recursiveUpdate { } [
    ollamaProviderSettings
    openaiProviderSettings
    anthropicProviderSettings
    googleProviderSettings
    groqProviderSettings
    mistralProviderSettings
    xaiProviderSettings
    togetherProviderSettings
    openrouterProviderSettings
    fireworksProviderSettings
    cerebrasProviderSettings
    clarifaiProviderSettings
    azureProviderSettings
  ];

in
{
  inherit
    allProviderSettings
    defaultOllamaModel
    ;
}
