import { execSync } from "node:child_process";

// Query LLM model pricing, usage limits, and capabilities from models.dev — the
// catalog that powers OpenCode's `/models` browser and https://opencode.ai/go.
// Shells out to the flake app `nix run .#opencode-models` (see
// packages/opencode-models/), so it works from within this repo.

function quote(s: string): string {
  return `'${s.replace(/'/g, "'\\''")}'`;
}

export default {
  description:
    "Look up LLM models with pricing (per 1M tokens), context/output limits, and capabilities (tool calling, vision, reasoning, structured output, open weights), ranked by cost-effectiveness. Data comes live from models.dev, the same catalog that powers opencode.ai/go. Defaults to the OpenCode Go provider. Use to pick the cheapest model for a given job (e.g. 'which opencode-go model handles vision cheapest?').",
  args: {
    action: {
      type: "string",
      description:
        "What to do: 'list' (ranked table, default), 'info' (full detail for one model), 'cheapest' (shortcut for list sorted by blend cost).",
    },
    model: {
      type: "string",
      description: "Model id to inspect (with action='info'), e.g. 'deepseek-v4-flash', 'mimo-v2.5'.",
    },
    provider: {
      type: "string",
      description: "Provider id from models.dev, or 'all' for the whole catalog. Default 'opencode-go' (the OpenCode Go subscription).",
    },
    sort: {
      type: "string",
      description: "Sort column: 'blend' (weighted $/1M mix, default), 'input', 'output', 'cache', 'context', or 'out'.",
    },
    capability: {
      type: "string",
      description: "Require a capability: 'tools', 'vision', 'multimodal', 'pdf', 'audio', 'reasoning', 'structured', 'weights', 'interleaved'. Comma-separate for AND.",
    },
    minContext: {
      type: "number",
      description: "Minimum context window, in tokens (e.g. 200000 for 200K).",
    },
    minOutput: {
      type: "number",
      description: "Minimum output limit, in tokens.",
    },
    maxInput: {
      type: "number",
      description: "Maximum input price, USD per 1M tokens.",
    },
    maxOutput: {
      type: "number",
      description: "Maximum output price, USD per 1M tokens.",
    },
    maxCache: {
      type: "number",
      description: "Maximum cache-read price, USD per 1M tokens.",
    },
    top: {
      type: "number",
      description: "Show only the top N results.",
    },
    refresh: {
      type: "boolean",
      description: "Bypass the on-disk cache and re-fetch models.dev.",
    },
  },
  async execute(args: {
    action?: string;
    model?: string;
    provider?: string;
    sort?: string;
    capability?: string;
    minContext?: number;
    minOutput?: number;
    maxInput?: number;
    maxOutput?: number;
    maxCache?: number;
    top?: number;
    refresh?: boolean;
  }) {
    try {
      const flakeDir = process.env.PWD || ".";
      const action = args.action || "list";

      if (action === "info") {
        if (!args.model) {
          return "opencode-models: action='info' requires the 'model' argument.";
        }
        const out = execSync(
          `nix run ${flakeDir}#opencode-models -- --info ${quote(args.model)} ${
            args.provider ? `--provider ${quote(args.provider)}` : ""
          } ${args.refresh ? "--refresh" : ""} 2>&1`,
          { encoding: "utf-8", timeout: 120_000, cwd: flakeDir, maxBuffer: 10 * 1024 * 1024 },
        );
        return out;
      }

      const flags: string[] = [];
      if (args.provider) flags.push(`--provider ${quote(args.provider)}`);
      const sort = args.sort || (action === "cheapest" ? "blend" : undefined) || "blend";
      flags.push(`--sort ${quote(sort)}`);
      if (args.capability) {
        for (const c of args.capability.split(",").map((x) => x.trim()).filter(Boolean)) {
          flags.push(`--capability ${quote(c)}`);
        }
      }
      if (args.minContext != null) flags.push(`--min-context ${args.minContext}`);
      if (args.minOutput != null) flags.push(`--min-output ${args.minOutput}`);
      if (args.maxInput != null) flags.push(`--max-input ${args.maxInput}`);
      if (args.maxOutput != null) flags.push(`--max-output ${args.maxOutput}`);
      if (args.maxCache != null) flags.push(`--max-cache ${args.maxCache}`);
      if (args.top != null) flags.push(`--top ${args.top}`);
      if (args.refresh) flags.push("--refresh");

      const out = execSync(
        `nix run ${flakeDir}#opencode-models -- ${flags.join(" ")} 2>&1`,
        { encoding: "utf-8", timeout: 120_000, cwd: flakeDir, maxBuffer: 10 * 1024 * 1024 },
      );
      return out;
    } catch (e: any) {
      const stderr = e.stderr || "";
      const stdout = e.stdout || "";
      return `opencode-models failed:\n${(stdout + stderr).trim()}`;
    }
  },
};
