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
    "Inspect a mod via the Modrinth API before adding it to a packwiz modpack: side (client/server/both), downloads, the latest version for the pack's loader+MC version, and dependencies. With --jar, also downloads the jar and lists the config/ files it ships so you know what it'll change.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'DragonTech')." },
    slug: { type: "string", description: "Modrinth slug or project name to inspect." },
    jar: { type: "string", description: "'true' to also download the jar and list its config files." },
  },
  async execute(args: { modpack?: string; slug?: string; jar?: string }) {
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "mc-pack.py");
    if (!args.modpack || !args.slug || !existsSync(modpackDir)) {
      return `packwiz-inspect-mod: need a valid modpack and slug.`;
    }
    const flag = args.jar === "true" ? "--jar" : "";
    try {
      const out = execSync(`python3 ${script} ${modpackDir} inspect ${args.slug} ${flag} 2>&1`, {
        encoding: "utf-8", cwd: modpackDir, timeout: 300_000, maxBuffer: 20 * 1024 * 1024,
      });
      return out.trim();
    } catch (e: any) {
      return `packwiz-inspect-mod failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
