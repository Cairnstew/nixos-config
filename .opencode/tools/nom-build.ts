import { tool } from "@opencode-ai/plugin";
import { execSync } from "node:child_process";

function runNom(worktree: string, cmd: string, timeout: number): string {
  const fullCmd = `nix shell nixpkgs#nix-output-monitor -c bash -c ${JSON.stringify(cmd + " 2>&1 | nom")}`;

  try {
    const out = execSync(fullCmd, {
      cwd: worktree,
      encoding: "utf-8",
      maxBuffer: 50 * 1024 * 1024,
      timeout,
      shell: "bash",
    });
    return out.trim();
  } catch (e: any) {
    const stderr = e.stderr || e.stdout || String(e);
    const combined = e.stdout ? `${e.stdout}\n${e.stderr || ""}` : stderr;
    return combined.trim() || `Command failed with exit code ${e.status || 1}`;
  }
}

export default tool({
  description:
    "Build Nix expressions with nix-output-monitor for pretty, structured build output. Shows timing, downloads, and build progress in a human-readable format. Use instead of raw nix build when you want to understand what's happening during a build.",

  args: {
    attr: tool.schema
      .string()
      .describe(
        "Flake attribute to build (e.g. 'nixosConfigurations.laptop.config.system.build.toplevel', 'packages.x86_64-linux.default'). Supports nixos-rebuild actions: 'switch', 'boot', 'test', 'build'."
      ),
    action: tool.schema
      .string()
      .optional()
      .default("build")
      .describe(
        "Build action: 'build' (nix build), 'switch' (nixos-rebuild switch), 'boot' (nixos-rebuild boot), 'test' (nixos-rebuild test). 'build' uses nix build; others use nixos-rebuild."
      ),
    extraArgs: tool.schema
      .string()
      .optional()
      .describe(
        "Extra CLI flags to pass through (e.g. '--no-build-nix', '--fast', '--show-trace')."
      ),
    timeout: tool.schema
      .number()
      .optional()
      .default(300_000)
      .describe("Timeout in milliseconds (default 300000 / 5 minutes)."),
  },

  async execute(args, context) {
    const { attr, action, extraArgs, timeout } = args;
    const worktree = context.worktree || context.directory;

    if (!attr) {
      return [
        "Provide the flake attribute to build.",
        "",
        "Examples:",
        '  attr: "nixosConfigurations.laptop.config.system.build.toplevel"',
        '  attr: "laptop"  action: "switch"',
        '  attr: "packages.x86_64-linux.default"',
      ].join("\n");
    }

    let cmd: string;
    if (action === "build") {
      const extras = extraArgs ? ` ${extraArgs}` : "";
      cmd = `nix build --no-write-lock-file "path:${worktree}#${attr}"${extras}`;
    } else {
      const extras = extraArgs ? ` ${extraArgs}` : "";
      cmd = `sudo nixos-rebuild ${action} --flake "path:${worktree}#${attr}"${extras}`;
    }

    return runNom(worktree, cmd, timeout ?? 300_000);
  },
});
