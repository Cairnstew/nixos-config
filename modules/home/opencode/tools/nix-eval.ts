import { execSync } from "node:child_process";

export default {
  description: "Safely evaluate Nix expressions or check flake outputs. Use this to validate Nix syntax, check attribute paths, and debug evaluation failures before committing changes.",
  args: {
    attr: {
      type: "string",
      description: "Flake output attribute path to evaluate (e.g. 'nixosConfigurations.laptop', 'packages.x86_64-linux.ventoy-deploy'). Mutually exclusive with 'expr'.",
    },
    expr: {
      type: "string",
      description: "Raw Nix expression to evaluate. Mutually exclusive with 'attr'.",
    },
    raw: {
      type: "boolean",
      description: "If true, return raw string output instead of JSON. Useful for non-JSON results.",
    },
  },
  async execute(args: { attr?: string; expr?: string; raw?: boolean }) {
    try {
      const flakeDir = process.env.PWD || ".";

      if (!args.attr && !args.expr) {
        return "nix-eval: Provide either 'attr' (flake attribute path) or 'expr' (raw Nix expression).";
      }

      let cmd: string;
      let isJson = false;

      if (args.attr) {
        cmd = `nix eval ${flakeDir}#${args.attr} --json 2>&1`;
        isJson = !args.raw;
      } else {
        // Sanity check the expression to avoid dangerous operations
        const expr = args.expr!;
        const dangerous = ["builtins.readFile", "builtins.readDir", "builtins.fetch", "import <", "abort", "throw", "builtins.derivation"];
        for (const pattern of dangerous) {
          if (expr.includes(pattern)) {
            return `nix-eval: Expression contains potentially dangerous operation (${pattern}). For safety, only pure evaluation is allowed.`;
          }
        }
        cmd = `nix eval --json --expr '${expr.replace(/'/g, "'\\''")}' 2>&1`;
        isJson = !args.raw;
      }

      const out = execSync(cmd, {
        encoding: "utf-8",
        timeout: 60_000,
        cwd: flakeDir,
        maxBuffer: 10 * 1024 * 1024,
      });

      if (isJson) {
        try {
          return JSON.stringify(JSON.parse(out), null, 2);
        } catch {
          return out;
        }
      }

      return out;
    } catch (e: any) {
      const stderr = e.stderr || "";
      const stdout = e.stdout || "";
      return `nix-eval failed:\n${(stdout + stderr).trim()}`;
    }
  },
};
