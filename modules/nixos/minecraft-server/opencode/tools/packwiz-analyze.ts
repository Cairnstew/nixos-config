import { execSync } from "node:child_process";
import { existsSync, appendFileSync, readFileSync } from "node:fs";
import { join } from "node:path";

function repoRoot(): string {
  try {
    const out = execSync("git rev-parse --show-toplevel 2>/dev/null", { encoding: "utf-8" }).trim();
    return out || process.env.PWD || ".";
  } catch {
    return process.env.PWD || ".";
  }
}

// ── Self-improvement ─────────────────────────────────────────────────────────
const SOURCE_REL = join("modules", "nixos", "minecraft-server", "opencode", "tools", "packwiz-analyze.ts");
const SKILL_REL = join("modules", "nixos", "minecraft-server", "opencode", "skill-mc-mod-analyze.md");

function appendRunLog(note: string): string {
  const repo = repoRoot();
  const src = join(repo, SOURCE_REL);
  const out: string[] = [];
  if (existsSync(src)) {
    const date = new Date().toISOString().slice(0, 10);
    try {
      const srcExisting = readFileSync(src, "utf-8");
      const srcHeader = srcExisting.includes("\n// ## RUN LOG") ? "" : "\n// ## RUN LOG\n";
      appendFileSync(src, `${srcHeader}// ### ${date}\n// ${note.replace(/\n/g, "\n// ")}\n`);
      out.push(`tool source ${src}`);
    } catch (e: any) {
      out.push(`tool source FAILED (${e.message})`);
    }
  }
  const skill = join(repo, SKILL_REL);
  if (existsSync(skill)) {
    try {
      const date = new Date().toISOString().slice(0, 10);
      const existing = readFileSync(skill, "utf-8");
      const header = existing.includes("\n## RUN LOG") ? "" : "\n## RUN LOG\n";
      appendFileSync(skill, `${header}\n### ${date}\n${note}\n`);
      out.push(`skill ${skill}`);
    } catch (e: any) {
      out.push(`skill FAILED (${e.message})`);
    }
  }
  return `packwiz-analyze: appended RUN LOG entry to ${out.join(" and ")}`;
}

export default {
  description:
    "Run all 7 extraction tools (ore, mobs, mobspawn, items, attributes, loot, recipes) against a packwiz modpack and merge the results into a single JSON document. Produces a unified modpack analysis covering ore gen, entity definitions, spawn rules, items/blocks, entity attributes, loot tables, and recipes. Use --tools to run a subset, or omit for all 7.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'AllTheTech')." },
    tools: { type: "string", description: "Comma-separated tools to run (default: all). Options: ore,mobs,mobspawn,items,attributes,loot,recipes." },
    fullExport: { type: "string", description: "Write merged output to a file. Pass a path or omit to default to <modpack>-analyze.json." },
    timeout: { type: "number", description: "Per-tool timeout in seconds (default: 300)." },
    note: { type: "string", description: "Self-improvement: append this note as a RUN LOG entry to the tool's source file AND its paired skill." },
  },
  async execute(args: { modpack?: string; tools?: string; fullExport?: string; timeout?: number; note?: string }) {
    if (args.note) {
      return appendRunLog(args.note);
    }
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "mc-pack-analyze.py");
    if (!args.modpack || !existsSync(modpackDir)) {
      return "packwiz-analyze: need a valid modpack.";
    }
    const argv: string[] = [];
    if (args.tools) argv.push("--tools", args.tools);
    if (args.fullExport !== undefined) argv.push("--full-export", args.fullExport || "");
    if (args.timeout) argv.push("--timeout", String(args.timeout));
    const quoted = argv.map((a) => `'${a.replace(/'/g, "'\\''")}'`).join(" ");
    try {
      const out = execSync(`python3 ${script} '${modpackDir}' ${quoted} 2>&1`, {
        encoding: "utf-8", cwd: modpackDir, timeout: 1800_000, maxBuffer: 50 * 1024 * 1024,
      });
      return out.trim();
    } catch (e: any) {
      return `packwiz-analyze failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
