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
// Mirrors the RUN LOG pattern in the mc-* launcher tools, scoped to this tool's
// source. The runtime copy (~/.config/opencode/tools/) is a read-only store
// symlink; the SOURCE of truth is the repo file:
//   modules/nixos/minecraft-server/opencode/tools/packwiz-mobspawn.ts
// When the agent discovers a bug or improvement while using this tool it should
// edit that repo file (not the runtime copy) and append a RUN LOG entry. A
// `note` argument appends the entry programmatically.

const SOURCE_REL = join("modules", "nixos", "minecraft-server", "opencode", "tools", "packwiz-mobspawn.ts");
// Paired skill doc this tool self-improves too (markdown RUN LOG entry).
const SKILL_REL = join("modules", "nixos", "minecraft-server", "opencode", "skill-mc-mod-mobspawn.md");

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
  return `packwiz-mobspawn: appended RUN LOG entry to ${out.join(" and ")}`;
}

export default {
  description:
    "Scan every mob spawn entry across all biomes a packwiz modpack will generate — from the pack's PINNED mod jars (checksums.json, exactly what players get) and its own datapacks (config/paxi/datapacks/ + any pack-level data/). Lists biomes with their spawner categories (monster, creature, ambient, etc.), flags contested placements (same biome file defined by multiple sources), and tracks resolution. Full-pack scans cache downloaded jars by checksum so re-runs are instant.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'AllTheTech')." },
    mods: { type: "string", description: "Comma-separated mod slugs to restrict the scan to (e.g. 'betternether,iceandfire'). Omit to scan the whole pack." },
    noDatapacks: { type: "boolean", description: "Skip scanning the pack's own datapacks (Paxi + data/)." },
    noVanilla: { type: "boolean", description: "Omit the embedded vanilla biome baseline." },
    list: { type: "boolean", description: "List all biome IDs with spawn data." },
    info: { type: "string", description: "Show spawn details for one biome (e.g. 'minecraft:plains')." },
    fullExport: { type: "string", description: "Write every biome's spawn data to a single JSON file. Pass an optional output path, or omit to default to <modpack>-mobspawn-full.json." },
    note: { type: "string", description: "Self-improvement: append this note as a RUN LOG entry to the tool's source file AND its paired skill (modules/nixos/minecraft-server/opencode/skill-mc-mod-mobspawn.md)." },
  },
  async execute(args: { modpack?: string; mods?: string; noDatapacks?: boolean; noVanilla?: boolean; list?: boolean; info?: string; fullExport?: string; note?: string }) {
    if (args.note) {
      return appendRunLog(args.note);
    }
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "mc-pack.py");
    if (!args.modpack || !existsSync(modpackDir)) {
      return `packwiz-mobspawn: need a valid modpack.`;
    }
    const argv = [args.fullExport !== undefined ? "mobspawn-full-export" : "mobspawn"];
    if (args.mods) argv.push("--mods", args.mods);
    if (args.noDatapacks) argv.push("--no-datapacks");
    if (args.noVanilla) argv.push("--no-vanilla");
    if (args.list) argv.push("--list");
    if (args.info) argv.push("--info", args.info);
    if (args.fullExport !== undefined && args.fullExport) argv.push(args.fullExport);
    const quoted = argv.map((a) => `'${a.replace(/'/g, "'\\''")}'`).join(" ");
    try {
      const out = execSync(`python3 ${script} ${modpackDir} ${quoted} 2>&1`, {
        encoding: "utf-8", cwd: modpackDir, timeout: 600_000, maxBuffer: 50 * 1024 * 1024,
      });
      return out.trim();
    } catch (e: any) {
      return `packwiz-mobspawn failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
