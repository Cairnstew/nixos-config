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
// Mirrors the RUN LOG pattern in packwiz-attributes.ts, scoped to this tool's
// source. The runtime copy (~/.config/opencode/tools/) is a read-only store
// symlink; the SOURCE of truth is the repo file:
//   modules/nixos/minecraft-server/opencode/tools/packwiz-item-components.ts
// A `note` argument appends the entry programmatically.

const SOURCE_REL = join("modules", "nixos", "minecraft-server", "opencode", "tools", "packwiz-item-components.ts");
// Paired skill doc this tool self-improves too (markdown RUN LOG entry).
const SKILL_REL = join("modules", "nixos", "minecraft-server", "opencode", "skill-mc-item-components.md");

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
  return `packwiz-item-components: appended RUN LOG entry to ${out.join(" and ")}`;
}

export default {
  description:
    "Read the cached item-components-dump.json and show an item-centric view of each item's default DataComponents: attribute modifiers (weapon/armor stat bonuses + magnitude), enchantability, tool mining data (level 0-4 + speed), food nutrition/saturation, and max stack size. " +
    "The dump is produced by item-componentsRegenerate (slow, ~30s + Nix FOD builds) which launches an isolated NeoForge server — the same launch harness as attributes-regenerate. " +
    "This tool reads the cached JSON and provides: --list (item IDs), --info (per-item component profile), --json (machine-readable), --full-export (complete JSON). " +
    "Full-pack scans are instant (reads cached JSON). Regenerate only when the mod list changes. " +
    "The item-tier tool consumes the same dump to compute an impact_score (recipe-centrality × component-magnitude).",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'AllTheTech')." },
    itemInfo: { type: "string", description: "Look up a single item by ID (e.g. 'minecraft:diamond_sword' or an artifacts/relics id) and return its full component profile." },
    mods: { type: "string", description: "Comma-separated item-id namespaces to restrict to (e.g. 'artifacts,relics' or 'minecraft')." },
    list: { type: "boolean", description: "Print just the item ids, one per line." },
    json: { type: "boolean", description: "Return a machine-readable JSON document." },
    fullExport: { type: "string", description: "Write every item's component summary to a single JSON file. Pass an optional output path, or omit to default to <modpack>-item-components-full.json." },
    itemComponentsRegenerate: { type: "boolean", description: "SLOW PATH (~30s server runtime + Nix FOD builds): Re-run the item component dump by launching an isolated NeoForge server. Use after mod list changes." },
    dryRun: { type: "boolean", description: "For itemComponentsRegenerate: print what would be done without doing it." },
    note: { type: "string", description: "Self-improvement: append this note as a RUN LOG entry to the tool's source file AND its paired skill (modules/nixos/minecraft-server/opencode/skill-mc-item-components.md)." },
  },
  async execute(args: {
    modpack?: string; itemInfo?: string; mods?: string; list?: boolean; json?: boolean;
    fullExport?: string; itemComponentsRegenerate?: boolean; dryRun?: boolean; note?: string;
  }) {
    if (args.note) {
      return appendRunLog(args.note);
    }
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    if (!args.modpack || !existsSync(modpackDir)) {
      return "packwiz-item-components: need a valid modpack.";
    }

    // ── item-components-regenerate (slow path) ─────────────────────────────
    if (args.itemComponentsRegenerate) {
      const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "attributes_dump.py");
      const argv = [modpackDir, "--dump-mod", "item-components-dump"];
      if (args.dryRun) argv.push("--dry-run");
      const quoted = argv.map((a) => `'${a.replace(/'/g, "'\\''")}'`).join(" ");
      try {
        const out = execSync(`python3 ${script} ${quoted} 2>&1`, {
          encoding: "utf-8", cwd: modpackDir, timeout: 2400_000, maxBuffer: 50 * 1024 * 1024,
        });
        return out.trim();
      } catch (e: any) {
        return `item-components-regenerate failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
      }
    }

    // ── item-components consumer (fast path) ──────────────────────────────
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "item-components.py");
    const argv: string[] = [];
    if (args.itemInfo) argv.push("--info", args.itemInfo);
    if (args.list) argv.push("--list");
    if (args.json) argv.push("--json");
    if (args.mods) argv.push("--mods", args.mods);
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
      return `packwiz-item-components failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};

// ## RUN LOG
// ### 2026-09-13
// Created as the opencode tool wrapper for item-components.py — mirrors
// packwiz-attributes.ts. Delegates to the standalone tools/item-components.py
// engine (same CLI, same flags). Args: modpack, itemInfo, mods, list, json,
// fullExport, itemComponentsRegenerate, dryRun, note. The regenerate path reuses
// attributes_dump.py --dump-mod item-components-dump (the exact attributes-dump
// launch/heap/logging harness — nothing reinvented).