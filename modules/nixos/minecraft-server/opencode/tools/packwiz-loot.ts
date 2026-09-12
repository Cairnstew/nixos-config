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
// Mirrors the RUN LOG pattern in packwiz-mobs / packwiz-structures, scoped to
// this tool's source. The runtime copy (~/.config/opencode/tools/) is a
// read-only store symlink; the SOURCE of truth is the repo file:
//   modules/nixos/minecraft-server/opencode/tools/packwiz-loot.ts
// When the agent discovers a bug or improvement while using this tool it should
// edit that repo file (not the runtime copy) and append a RUN LOG entry. A
// `note` argument appends the entry programmatically.

const SOURCE_REL = join("modules", "nixos", "minecraft-server", "opencode", "tools", "packwiz-loot.ts");
// Paired skill doc this tool self-improves too (markdown RUN LOG entry).
const SKILL_REL = join("modules", "nixos", "minecraft-server", "opencode", "skill-mc-mod-loot.md");

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
  return `packwiz-loot: appended RUN LOG entry to ${out.join(" and ")}`;
}

export default {
  description:
    "List every loot table a packwiz modpack will include — vanilla baseline for the pack's MC version PLUS the pack's PINNED mod jars (checksums.json, exactly what players get) and its own datapacks (config/paxi/datapacks/ + any pack-level data/). Reports total count, count by mod and type (block/entity/chest/gameplay), loot entries referencing unresolved items, empty/produce-nothing tables, and vanilla overrides. With lootInfo, look up a single loot table's full metadata (type, pools, entries, items, conditions, source, override status, raw JSON). Backed by the standalone python3 tools/loot.py (same output; add json=true for machine-readable). Full-pack scans cache downloaded jars by checksum so re-runs are instant.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'AllTheTech')." },
    lootInfo: { type: "string", description: "Look up a single loot table by ID (e.g. 'minecraft:blocks/diamond_ore' or 'ae2:creative_energy_cell') and return all known metadata: type, pools, entries, items, conditions, source, override status, raw JSON." },
    mods: { type: "string", description: "Comma-separated mod slugs to restrict the jar scan to (e.g. 'ae2,still-life'). Omit to scan the whole pack." },
    noDatapacks: { type: "boolean", description: "Skip scanning the pack's own datapacks (Paxi + data/)." },
    noVanilla: { type: "boolean", description: "Omit the embedded vanilla loot tables baseline for the pack's MC version." },
    list: { type: "boolean", description: "Print just the loot table ids, one per line (combine with noVanilla for only mod-added ones)." },
    json: { type: "boolean", description: "Return a machine-readable JSON document (pack, per-source loot tables, summary). For lootInfo, returns the full lookup result as JSON." },
    fullExport: { type: "string", description: "Write every loot table's full metadata to a single JSON file. Pass an optional output path, or omit to default to <modpack>-loot-full.json." },
    note: { type: "string", description: "Self-improvement: append this note as a RUN LOG entry to the tool's source file AND its paired skill (modules/nixos/minecraft-server/opencode/skill-mc-mod-loot.md)." },
  },
  async execute(args: { modpack?: string; lootInfo?: string; mods?: string; noDatapacks?: boolean; noVanilla?: boolean; list?: boolean; json?: boolean; fullExport?: string; note?: string }) {
    if (args.note) {
      return appendRunLog(args.note);
    }
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "loot.py");
    if (!args.modpack || !existsSync(modpackDir)) {
      return `packwiz-loot: need a valid modpack.`;
    }
    const argv = [];
    if (args.lootInfo) argv.push("--info", args.lootInfo);
    if (args.mods) argv.push("--mods", args.mods);
    if (args.noDatapacks) argv.push("--no-datapacks");
    if (args.noVanilla) argv.push("--no-vanilla");
    if (args.list) argv.push("--list");
    if (args.json) argv.push("--json");
    if (args.fullExport !== undefined) {
      argv.push("--full-export");
      if (args.fullExport) argv.push(args.fullExport);
    }
    const quoted = argv.map((a) => `'${a.replace(/'/g, "'\\''")}'`).join(" ");
    try {
      const out = execSync(`python3 ${script} ${modpackDir} ${quoted} 2>&1`, {
        encoding: "utf-8", cwd: modpackDir, timeout: 600_000, maxBuffer: 50 * 1024 * 1024,
      });
      return out.trim();
    } catch (e: any) {
      return `packwiz-loot failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};

// ## RUN LOG
// ### 2026-09-07
// Created as the opencode tool wrapper for loot.py — mirrors packwiz-items
// architecture. Delegates to the standalone tools/loot.py engine (same CLI,
// same flags). Args: modpack, lootInfo, mods, noDatapacks, noVanilla, list,
// json, note. Self-improvement wiring matches packwiz-items (appendRunLog
// writes to this .ts + skill-mc-mod-loot.md).
