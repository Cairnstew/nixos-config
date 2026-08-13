import { execSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

function repoRoot(): string {
  try {
    const out = execSync("git rev-parse --show-toplevel 2>/dev/null", { encoding: "utf-8" }).trim();
    return out || process.env.PWD || ".";
  } catch {
    return process.env.PWD || ".";
  }
}

export default {
  description:
    "Set or clear the `preserve` flag on a config file's index.toml entry. preserve=true installs the file only if it doesn't already exist, so player edits win (they never get your improved defaults later). preserve=false (default packwiz behavior) overwrites player copies on every reinstall. packwiz has no CLI for this — it's an index.toml property.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'testModpack')." },
    relPath: { type: "string", description: "Path under config/, e.g. 'jei/jei.toml'." },
    on: { type: "string", description: "'on' (default) or 'off'." },
  },
  async execute(args: { modpack?: string; relPath?: string; on?: string }) {
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "mc-pack.py");
    if (!args.modpack || !args.relPath || !existsSync(modpackDir)) {
      return `packwiz-config-preserve: need a valid modpack and relPath.`;
    }
    try {
      const on = args.on && args.on !== "on" && args.on !== "" ? "off" : "on";
      const out = execSync(`python3 ${script} ${modpackDir} config-preserve ${args.relPath} ${on} 2>&1`, {
        encoding: "utf-8", cwd: modpackDir, timeout: 60_000,
      });
      return out.trim();
    } catch (e: any) {
      return `packwiz-config-preserve failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
