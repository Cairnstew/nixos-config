import { tool } from "@opencode-ai/plugin";
import { execSync } from "node:child_process";

function runPkg(pkg: string, args: string[], worktree: string, timeout: number): string {
  const cmd = `nix run nixpkgs#${pkg} -- ${args.map((a) => JSON.stringify(a)).join(" ")}`;
  try {
    const out = execSync(cmd, { cwd: worktree, encoding: "utf-8", timeout, shell: "bash" });
    return out.trim();
  } catch (e: any) {
    return e.stderr?.trim() || e.stdout?.trim() || `Exit code ${e.status || 1}`;
  }
}

export default tool({
  description:
    "Generate Nix package expressions from source URLs. Uses nix-init to create a full package.nix (with hash prefetching, license detection, dependency inference) or nurl to generate a single fetcher call (fetchFromGitHub, fetchurl, etc.).",

  args: {
    url: tool.schema
      .string()
      .describe("Source URL (e.g. 'https://github.com/user/repo'). For nix-init, supports GitHub, GitLab, SourceHut, and more."),
    rev: tool.schema
      .string()
      .optional()
      .describe("Git revision, tag, or branch to fetch (e.g. 'v1.0.0', 'main', commit SHA)."),
    mode: tool.schema
      .string()
      .optional()
      .default("nurl")
      .describe(
        "'nurl' (default) — generate a fetcher call expression like fetchFromGitHub. 'nix-init' — generate a full package.nix with metadata, license detection, and build instructions."
      ),
    output: tool.schema
      .string()
      .optional()
      .describe("Output path for nix-init. Defaults to stdout (printed, not saved). For nix-init, set to a file path to write the package expression."),
    pname: tool.schema
      .string()
      .optional()
      .describe("Package name (for nix-init mode). Auto-detected from URL if omitted."),
    builder: tool.schema
      .string()
      .optional()
      .describe("Builder type (for nix-init mode). E.g. 'stdenv.mkDerivation', 'buildRustPackage', 'buildPythonApplication'. Auto-detected if omitted."),
  },

  async execute(args, context) {
    const { url, rev, mode, output, pname, builder } = args;
    const worktree = context.worktree || context.directory;

    if (!url) {
      return [
        "Provide a URL to generate a Nix expression from.",
        "",
        "Examples:",
        '  url: "https://github.com/org/tool"            # fetcher call only',
        '  url: "https://github.com/org/tool"  mode: "nix-init"  # full package',
        '  url: "https://github.com/org/tool"  rev: "v2.0.0"     # specific tag',
      ].join("\n");
    }

    if (mode === "nix-init") {
      const initArgs: string[] = ["--headless", "--url", url];
      if (rev) initArgs.push("--rev", rev);
      if (pname) initArgs.push("--pname", pname);
      if (builder) initArgs.push("--builder", builder);
      if (output) initArgs.push(output);

      const result = runPkg("nix-init", initArgs, worktree, 120_000);

      if (result.includes("error") || result.includes("Error")) {
        return [
          "nix-init encountered an issue:",
          "",
          result,
          "",
          "Tip: Try with mode: 'nurl' first to verify the URL works, then upgrade to nix-init.",
        ].join("\n");
      }

      return [
        `Generated package expression for ${url}:`,
        "",
        result,
        "",
        output ? `Written to: ${output}` : "Output shown above (pass --output to save to a file).",
      ].join("\n");
    }

    const nurlArgs: string[] = [url];
    if (rev) nurlArgs.push(rev);

    const result = runPkg("nurl", nurlArgs, worktree, 60_000);

    if (result.includes("error") || result.includes("Error")) {
      return [
        `Could not generate fetcher for "${url}".`,
        "",
        result,
        "",
        "Try a different URL format or use nix-init mode for more robust handling.",
      ].join("\n");
    }

    let hint = "";
    if (result.includes("fetchFromGitHub")) {
      hint = "For a full package expression, use mode: 'nix-init'.";
    }

    return [
      `Fetcher call for ${url}:`,
      "",
      result,
      "",
      hint,
    ].join("\n");
  },
});
