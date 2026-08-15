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
// Mirrors the RUN LOG pattern in the mc-* launcher tools / packwiz-structures,
// scoped to this tool's source. The runtime copy (~/.config/opencode/tools/) is
// a read-only store symlink; the SOURCE of truth is the repo file:
//   modules/nixos/minecraft-server/opencode/tools/packwiz-controls.ts
// When the agent discovers a bug or improvement while using this tool it should
// edit that repo file (not the runtime copy) and append a RUN LOG entry. A
// `note` argument appends the entry programmatically.

const SOURCE_REL = join("modules", "nixos", "minecraft-server", "opencode", "tools", "packwiz-controls.ts");
// Paired skill doc this tool self-improves too (markdown RUN LOG entry).
const SKILL_REL = join("modules", "nixos", "minecraft-server", "opencode", "skill-mc-mod-controls.md");

function appendRunLog(note: string): string {
  const repo = repoRoot();
  const src = join(repo, SOURCE_REL);
  const out: string[] = [];
  if (existsSync(src)) {
    const date = new Date().toISOString().slice(0, 10);
    try {
      appendFileSync(src, `\n// ## RUN LOG\n// ### ${date}\n// ${note.replace(/\n/g, "\n// ")}\n`);
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
  return `packwiz-controls: appended RUN LOG entry to ${out.join(" and ")}`;
}

export default {
  description:
    "Review the default hotkeys and controls for a whole packwiz modpack — every keybinding (vanilla + mods) with its bound key, decoded to human-readable, grouped into vanilla/mod, plus a conflict report for keys bound more than once. Reads the effective bindings from the pack's shipped options.txt (if it ships one) or a generated one from the pack's Prism instance (or an explicit --options path), and resolves each keybind id to a label + owning mod via the pinned jars' lang files. Use to see what controls players get before shipping a default.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'testModpack')." },
    options: { type: "string", description: "Explicit path to an options.txt to review instead of auto-detecting." },
    dataDir: { type: "string", description: "Prism Launcher data dir override for instance auto-detection (default: auto-detect from known locations)." },
    mod: { type: "string", description: "Only show keybindings for this mod (slug/modid substring, e.g. 'iris')." },
    note: { type: "string", description: "Self-improvement: append this note as a RUN LOG entry to the tool's source file AND its paired skill (modules/nixos/minecraft-server/opencode/skill-mc-mod-controls.md)." },
  },
  async execute(args: { modpack?: string; options?: string; dataDir?: string; mod?: string; note?: string }) {
    if (args.note) {
      return appendRunLog(args.note);
    }
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "mc-pack.py");
    if (!args.modpack || !existsSync(modpackDir)) {
      return `packwiz-controls: need a valid modpack.`;
    }
    const argv = ["controls"];
    if (args.options) argv.push("--options", args.options);
    if (args.dataDir) argv.push("--dataDir", args.dataDir);
    if (args.mod) argv.push("--mod", args.mod);
    const quoted = argv.map((a) => `'${a.replace(/'/g, "'\\''")}'`).join(" ");
    try {
      const out = execSync(`python3 ${script} ${modpackDir} ${quoted} 2>&1`, {
        encoding: "utf-8", cwd: modpackDir, timeout: 600_000, maxBuffer: 50 * 1024 * 1024,
      });
      return out.trim();
    } catch (e: any) {
      return `packwiz-controls failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
