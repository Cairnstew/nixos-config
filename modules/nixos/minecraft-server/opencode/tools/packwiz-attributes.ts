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
// Mirrors the RUN LOG pattern in packwiz-mobs.ts / packwiz-structures.ts,
// scoped to this tool's source. The runtime copy (~/.config/opencode/tools/) is
// a read-only store symlink; the SOURCE of truth is the repo file:
//   modules/nixos/minecraft-server/opencode/tools/packwiz-attributes.ts
// When the agent discovers a bug or improvement while using this tool it should
// edit that repo file (not the runtime copy) and append a RUN LOG entry. A
// `note` argument appends the entry programmatically.

const SOURCE_REL = join("modules", "nixos", "minecraft-server", "opencode", "tools", "packwiz-attributes.ts");
// Paired skill doc this tool self-improves too (markdown RUN LOG entry).
const SKILL_REL = join("modules", "nixos", "minecraft-server", "opencode", "skill-mc-mod-attributes.md");

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
  return `packwiz-attributes: appended RUN LOG entry to ${out.join(" and ")}`;
}

export default {
  description:
    "Read the cached entity-attributes dump (attributes-dump.json) and show an entity-centric view with source classification. " +
    "The dump is produced by attributes-regenerate (slow, ~30s) which launches an isolated NeoForge server. " +
    "This tool reads the cached JSON and provides: --list (entity IDs), --info (per-entity attribute profile), " +
    "--json (machine-readable), --full-export (complete JSON). Entities are classified as vanilla or modded " +
    "(cross-referenced against the vanilla baseline). For each entity, non-default attributes are highlighted " +
    "to surface what mods actually changed. Full-pack scans are instant (reads cached JSON). " +
    "Use attributesRegenerate to refresh the dump after mod list changes.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'AllTheTech')." },
    entityInfo: { type: "string", description: "Look up a single entity by ID (e.g. 'minecraft:zombie' or 'iceandfire:fire_dragon') and return its full attribute profile." },
    noVanilla: { type: "boolean", description: "Exclude vanilla entities (only show modded-added)." },
    list: { type: "boolean", description: "Print just the entity ids, one per line (combine with noVanilla for only mod-added ones)." },
    json: { type: "boolean", description: "Return a machine-readable JSON document (pack, per-entity attributes, summary)." },
    fullExport: { type: "string", description: "Write every entity's full attribute data to a single JSON file. Pass an optional output path, or omit to default to <modpack>-attributes-full.json." },
    showAll: { type: "boolean", description: "Show all attributes including defaults (for --entityInfo)." },
    attribute: { type: "string", description: "Filter --entityInfo to specific attribute(s) by substring match (can repeat)." },
    attributesRegenerate: { type: "boolean", description: "SLOW PATH (~30s): Re-run the attribute dump by launching an isolated NeoForge server. Use after mod list changes." },
    dryRun: { type: "boolean", description: "For attributesRegenerate: print what would be done without doing it." },
    note: { type: "string", description: "Self-improvement: append this note as a RUN LOG entry to the tool's source file AND its paired skill (modules/nixos/minecraft-server/opencode/skill-mc-mod-attributes.md)." },
  },
  async execute(args: {
    modpack?: string; entityInfo?: string; noVanilla?: boolean; list?: boolean;
    json?: boolean; fullExport?: string; showAll?: boolean; attribute?: string;
    attributesRegenerate?: boolean; dryRun?: boolean; note?: string;
  }) {
    if (args.note) {
      return appendRunLog(args.note);
    }
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    if (!args.modpack || !existsSync(modpackDir)) {
      return "packwiz-attributes: need a valid modpack.";
    }

    // ── attributes-regenerate (slow path) ─────────────────────────────────
    if (args.attributesRegenerate) {
      const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "attributes_dump.py");
      const argv = [modpackDir];
      if (args.dryRun) argv.push("--dry-run");
      const quoted = argv.map((a) => `'${a.replace(/'/g, "'\\''")}'`).join(" ");
      try {
        const out = execSync(`python3 ${script} ${quoted} 2>&1`, {
          encoding: "utf-8", cwd: modpackDir, timeout: 2400_000, maxBuffer: 50 * 1024 * 1024,
        });
        return out.trim();
      } catch (e: any) {
        return `attributes-regenerate failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
      }
    }

    // ── attributes consumer (fast path) ───────────────────────────────────
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "attributes.py");
    const argv: string[] = [];
    if (args.entityInfo) argv.push("--info", args.entityInfo);
    if (args.noVanilla) argv.push("--no-vanilla");
    if (args.list) argv.push("--list");
    if (args.json) argv.push("--json");
    if (args.showAll) argv.push("--show-all");
    if (args.attribute) {
      // Support multiple --attribute flags
      for (const a of args.attribute.split(",")) {
        argv.push("--attribute", a.trim());
      }
    }
    if (args.fullExport !== undefined) {
      argv.push("--full-export");
      if (args.fullExport) argv.push(args.fullExport);
    }
    const quoted = argv.map((a) => `'${a.replace(/'/g, "'\\''")}'`).join(" ");
    try {
      const out = execSync(`python3 ${script} ${modpackDir} ${quoted} 2>&1`, {
        encoding: "utf-8", cwd: modpackDir, timeout: 30_000, maxBuffer: 50 * 1024 * 1024,
      });
      return out.trim();
    } catch (e: any) {
      return `packwiz-attributes failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};

// ## RUN LOG
// ### 2026-09-08
// Created as the opencode tool wrapper for attributes.py — mirrors packwiz-mobs.ts
// architecture. Delegates to the standalone tools/attributes.py engine (same CLI,
// same flags). Args: modpack, entityInfo, noVanilla, list, json, fullExport,
// showAll, attribute, attributesRegenerate, dryRun, note. Self-improvement wiring
// matches packwiz-mobs (appendRunLog writes to this .ts + skill-mc-mod-attributes.md).
// ### 2026-09-12
// log4j2 RollingFile never flushed buffer (100MB threshold vs 63KB actual). All log output
// after initial 2s was lost in memory — JVM ran 598s but only 2s of log on disk. Fix:
// added immediateFlush="true" to both RollingFile appenders in attributes_dump.py.
// Also confirmed: AttributesDump hooks FMLLoadCompleteEvent (before world gen), so the
// entire ~541s is mod loading time, not world gen.
