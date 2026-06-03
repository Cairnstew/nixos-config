import { tool } from "@opencode-ai/plugin";
import { execSync } from "node:child_process";

export default tool({
  description:
    "Safely evaluate Nix expressions or check flake outputs. Handles common evaluation errors from GOTCHAS.md and returns structured results instead of raw CLI output. Use this to validate Nix syntax, check attribute paths, and debug evaluation failures before committing changes.",

  args: {
    attr: tool.schema
      .string()
      .optional()
      .describe(
        "Flake output attribute path to evaluate (e.g. 'nixosConfigurations.laptop', 'packages.x86_64-linux.ventoy-deploy'). Mutually exclusive with 'expr'."
      ),
    expr: tool.schema
      .string()
      .optional()
      .describe(
        "Raw Nix expression to evaluate (e.g. 'builtins.attrNames (import <nixpkgs> {}).pkgs'). Mutually exclusive with 'attr'."
      ),
    raw: tool
      .schema
      .boolean()
      .optional()
      .default(false)
      .describe(
        "If true, return raw string output instead of JSON. Useful for non-JSON results like --readonly-mode."
      ),
    apply: tool.schema
      .string()
      .optional()
      .describe("Apply a function to the result: `nix eval --apply 'f'`"),
  },

  async execute(args, context) {
    const { attr, expr, raw, apply } = args;
    const worktree = context.worktree || context.directory;

    if (!attr && !expr) {
      return "Provide either `attr` (flake attribute path) or `expr` (raw Nix expression).";
    }

    let cmd = "nix eval --no-write-lock-file";
    if (raw) cmd += " --raw";
    if (!raw) cmd += " --json";
    if (apply) cmd += ` --apply '${apply.replace(/'/g, "'\\''")}'`;

    if (attr) {
      if (attr.startsWith(".")) {
        cmd += ` path:${worktree}${attr}`;
      } else if (attr.includes("#")) {
        cmd += ` ${attr}`;
      } else {
        cmd += ` path:${worktree}#${attr}`;
      }
    } else {
      cmd += ` --expr '${expr!.replace(/'/g, "'\\''")}'`;
    }

    try {
      const stdout = execSync(cmd, {
        cwd: worktree,
        encoding: "utf-8",
        maxBuffer: 10 * 1024 * 1024,
        timeout: 60_000,
      });

      if (raw) return stdout.trim();

      try {
        const parsed = JSON.parse(stdout);
        return JSON.stringify(parsed, null, 2);
      } catch {
        return stdout.trim();
      }
    } catch (e: any) {
      const stderr = e.stderr || "";
      const isSyntax = /syntax error|parse error/i.test(stderr);
      const isMissing = /does not provide attribute|attribute .* missing/i.test(stderr);
      const isAssertion = /assertion failed/i.test(stderr);
      const isType = /type error|type mismatch/i.test(stderr);
      const isUndefined = /undefined variable/i.test(stderr);
      const isInfinite = /infinite recursion/i.test(stderr);
      const isRepoMissing = /does not provide attribute/i.test(stderr);
      const isNixFlake = /error:.*(flake|lock).*/i.test(stderr);

      const hints: string[] = [];
      if (isSyntax) hints.push("Nix syntax error. Check braces, semicolons, and string interpolation.");
      if (isMissing) hints.push("The attribute path does not exist. Use nix-hosts or nix-modules tool to discover available outputs.");
      if (isAssertion) hints.push("An assertion failed — likely conflicting profiles (e.g. gpu.mesa + gpu.nvidia) or missing required options.");
      if (isType) hints.push("Type mismatch — expected one type but got another (e.g. string vs int).");
      if (isUndefined) hints.push("Referenced a variable that isn't in scope. Check let-bindings and function arguments.");
      if (isInfinite) hints.push("Infinite recursion. Check for circular imports or self-referencing options.");
      if (isRepoMissing) hints.push("Flake output not found. Ensure the file is staged with 'git add' (Nix flakes only see committed/staged files).");
      if (isNixFlake) hints.push("Flake/lock file issue. Try 'nix flake lock' to update.");

      return [
        `Nix evaluation failed with exit code ${e.status || 1}:`,
        "",
        stderr.trim(),
        ...(hints.length > 0
          ? ["", "Hints:", ...hints.map((h) => `  - ${h}`)]
          : []),
      ].join("\n");
    }
  },
});
