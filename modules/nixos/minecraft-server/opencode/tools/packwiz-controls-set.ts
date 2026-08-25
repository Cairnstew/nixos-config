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
//   modules/nixos/minecraft-server/opencode/tools/packwiz-controls-set.ts
// When the agent discovers a bug or improvement while using this tool it should
// edit that repo file (not the runtime copy) and append a RUN LOG entry. A
// `note` argument appends the entry programmatically.

const SOURCE_REL = join("modules", "nixos", "minecraft-server", "opencode", "tools", "packwiz-controls-set.ts");
// Paired skill doc this tool self-improves too (markdown RUN LOG entry).
const SKILL_REL = join("modules", "nixos", "minecraft-server", "opencode", "skill-mc-mod-controls-set.md");

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
  return `packwiz-controls-set: appended RUN LOG entry to ${out.join(" and ")}`;
}

export default {
  description:
    "Set the default hotkeys/controls a packwiz modpack ships to players. Writes the pack's default options.txt at the PACK ROOT (which maps to the game root on install — not under config/), refreshes the index, and optionally marks it preserve so players who already have an options.txt keep their edits. Use --key key_<id>=<code> for one-off binding overrides or --from <file> to seed from a tuned/generated options.txt. The write step that pairs with the packwiz-controls review tool.",
  args: {
    modpack: { type: "string", description: "Modpack directory name (e.g. 'AllTheTech')." },
    keys: { type: "string", description: "Space-separated keybind overrides, e.g. 'key_key.sneak=key.keyboard.left.control key_iris.keybind.reload=key.keyboard.r'. Optional if --from is given." },
    from: { type: "string", description: "Absolute path to a source options.txt (e.g. a tuned instance's generated one) to seed the pack default from. Optional if keys is given." },
    preserve: { type: "boolean", description: "Mark the index entry preserve=true so players' existing copies are never overwritten (default false = the pack's default is enforced on every install)." },
    note: { type: "string", description: "Self-improvement: append this note as a RUN LOG entry to the tool's source file AND its paired skill (modules/nixos/minecraft-server/opencode/skill-mc-mod-controls-set.md)." },
  },
  async execute(args: { modpack?: string; keys?: string; from?: string; preserve?: boolean; note?: string }) {
    if (args.note) {
      return appendRunLog(args.note);
    }
    const repo = repoRoot();
    const modpackDir = join(repo, "modules", "nixos", "minecraft-server", "modpacks", args.modpack || "");
    const script = join(repo, "modules", "nixos", "minecraft-server", "opencode", "tools", "mc-pack.py");
    if (!args.modpack || !existsSync(modpackDir)) {
      return `packwiz-controls-set: need a valid modpack.`;
    }
    const argv = ["controls-set"];
    if (args.keys) {
      for (const kv of args.keys.split(/\s+/).filter(Boolean)) argv.push("--key", kv);
    }
    if (args.from) argv.push("--from", args.from);
    if (args.preserve) argv.push("--preserve");
    const quoted = argv.map((a) => `'${a.replace(/'/g, "'\\''")}'`).join(" ");
    try {
      const out = execSync(`python3 ${script} ${modpackDir} ${quoted} 2>&1`, {
        encoding: "utf-8", cwd: modpackDir, timeout: 900_000, maxBuffer: 20 * 1024 * 1024,
      });
      return out.trim();
    } catch (e: any) {
      return `packwiz-controls-set failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
    }
  },
};
