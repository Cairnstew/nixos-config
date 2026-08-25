import { existsSync, readdirSync, readFileSync, statSync, appendFileSync } from "node:fs";
import { execSync } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";

// ── Self-improvement ─────────────────────────────────────────────────────────
// Mirrors the researcher agent's SELF_IMPROVE + RUN LOG pattern, scoped to this
// tool's source. The runtime copy (~/.config/opencode/tools/) is a read-only
// store symlink; the SOURCE of truth is the repo file:
//   modules/nixos/minecraft-server/opencode/tools/mc-prism-log.ts
// When the agent discovers a bug or improvement while using this tool it should
// edit that repo file (not the runtime copy) and append a RUN LOG entry. A
// `note` argument appends the entry programmatically.

const SOURCE_REL = join("modules", "nixos", "minecraft-server", "opencode", "tools", "mc-prism-log.ts");
// Paired skill doc this tool self-improves too (markdown RUN LOG entry).
const SKILL_REL = join("modules", "nixos", "minecraft-server", "opencode", "skill.md");

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
  return `mc-prism-log: appended RUN LOG entry to ${out.join(" and ")}`;
}

// ── Shared helpers (kept in-file: opencode copies each tool to
// ~/.config/opencode/tools/ individually, so sibling imports don't resolve) ──

function repoRoot(): string {
  try {
    const out = execSync("git rev-parse --show-toplevel 2>/dev/null", { encoding: "utf-8" }).trim();
    return out || process.env.PWD || ".";
  } catch {
    return process.env.PWD || ".";
  }
}

function dataDirCandidates(): string[] {
  const home = homedir();
  return [
    process.env.PRISMLAUNCHER_DIR || "",
    "/mnt/media/Modding/PrismLauncher",
    "/mnt/data/prismlauncher",
    join(home, ".local", "share", "PrismLauncher"),
    join(home, ".var", "app", "org.prismlauncher.PrismLauncher", "data", "PrismLauncher"),
  ].filter(Boolean);
}

function findDataDir(): string | null {
  for (const dir of dataDirCandidates()) {
    if (existsSync(join(dir, "instances"))) return dir;
  }
  return null;
}

function listInstances(dataDir: string): string[] {
  const dir = join(dataDir, "instances");
  return existsSync(dir)
    ? readdirSync(dir, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name)
    : [];
}

function findInstanceDir(dataDir: string, modpack: string): string | null {
  const dirs = listInstances(dataDir);
  if (dirs.length === 0) return null;
  const exact = dirs.find((d) => d === modpack);
  if (exact) return join(dataDir, "instances", exact);
  const lower = dirs.find((d) => d.toLowerCase() === modpack.toLowerCase());
  if (lower) return join(dataDir, "instances", lower);
  for (const d of dirs) {
    const cfg = join(dataDir, "instances", d, "instance.cfg");
    if (!existsSync(cfg)) continue;
    const m = readFileSync(cfg, "utf-8").match(/^name=(.*)$/m);
    if (m && m[1] === modpack) return join(dataDir, "instances", d);
  }
  return null;
}

// Best-effort pack → server-name mapping by scanning repo nix for
// `servers.<name> = { ... packwiz = ...modpacks/<pack>`.
function findServerForPack(repo: string, modpack: string): string | null {
  const target = `modpacks/${modpack}`;
  const walk = (dir: string): string[] => {
    const out: string[] = [];
    for (const e of readdirSync(dir, { withFileTypes: true })) {
      if (e.name.startsWith(".")) continue;
      const p = join(dir, e.name);
      if (e.isDirectory()) out.push(...walk(p));
      else out.push(p);
    }
    return out;
  };
  for (const root of [join(repo, "modules", "nixos", "minecraft-server", "servers"), join(repo, "configurations")]) {
    if (!existsSync(root)) continue;
    for (const file of walk(root)) {
      if (!file.endsWith(".nix")) continue;
      let text = "";
      try {
        text = readFileSync(file, "utf-8");
      } catch {
        continue;
      }
      if (!text.includes(target)) continue;
      const m = text.match(/servers\.([A-Za-z0-9_-]+)\s*=\s*{/);
      if (m) return m[1];
    }
  }
  return null;
}

function findServerLogDir(): string | null {
  for (const dir of ["/mnt/data/minecraft", "/var/lib/minecraft", join(homedir(), ".minecraft-server")]) {
    if (existsSync(dir)) return dir;
  }
  return null;
}

function newestFile(dir: string): string | null {
  const files = existsSync(dir)
    ? readdirSync(dir).filter((f) => !f.endsWith(".gz")).map((f) => join(dir, f))
    : [];
  if (files.length === 0) return null;
  files.sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs);
  return files[0];
}

// ── Server-side log fallback (no Prism on this host) ────────────────────────
// The same modpack can run as a dedicated server via
// my.services.minecraftServer.servers.<name>.packwiz = ../modpacks/<pack>.
// Server logs live at <dataDir>/<server>/logs/{latest,debug}.log, and the
// systemd unit's stdout is in journald.
function serverLogs(modpack: string, server?: string, filter?: string, tail = 100): string {
  const unitName = server || findServerForPack(repoRoot(), modpack);
  if (!unitName) {
    return `mc-prism-log: no Prism instance for '${modpack}' AND no minecraft server configured for it — cannot find logs.`;
  }
  const parts: string[] = [];

  const dataDir = findServerLogDir();
  if (dataDir) {
    for (const sub of [unitName, modpack]) {
      const logsDir = join(dataDir, sub, "logs");
      if (!existsSync(logsDir)) continue;
      const readOne = (name: string, path: string) => {
        if (!existsSync(path)) return;
        const lines = readFileSync(path, "utf-8").split("\n");
        let sel = lines;
        if (filter) {
          try {
            const re = new RegExp(filter);
            sel = lines.filter((l) => re.test(l));
          } catch {
            sel = lines.filter((l) => l.includes(filter));
          }
        }
        parts.push(`${name}${filter ? ` (${sel.length} matching '${filter}')` : ""} — last ${Math.min(tail, sel.length)} of ${lines.length} lines:\n${sel.slice(-tail).join("\n")}`);
      };
      readOne(`${sub} latest.log`, join(logsDir, "latest.log"));
      readOne(`${sub} debug.log`, join(logsDir, "debug.log"));
      break;
    }
  }

  try {
    const journal = execSync(
      `journalctl -u minecraft-server-${unitName}.service -n ${tail} --no-pager 2>/dev/null`,
      { encoding: "utf-8", timeout: 15_000 }
    );
    if (journal.trim()) parts.push(`journald minecraft-server-${unitName} (last ${tail}):\n${journal.trim()}`);
  } catch {
    /* no journald access or no such unit */
  }

  return parts.length
    ? `Server logs for '${modpack}' (unit minecraft-server-${unitName}):\n\n` + parts.join("\n\n=====\n\n")
    : `mc-prism-log: no Prism instance for '${modpack}' and no server logs found for unit minecraft-server-${unitName}.`;
}

export default {
  description:
    "Read the latest Minecraft log for a packwiz modpack. Tries the Prism Launcher instance for the modpack first (latest.log / debug.log / newest crash report); if Prism Launcher is NOT available on this host, falls back to the dedicated server logs (minecraft-server-<name> unit) — both the on-disk latest.log and journald. Use to diagnose a launch crash or startup error.",
  args: {
    modpack: {
      type: "string",
      description: "Modpack name (maps to the Prism Launcher instance and/or the minecraft-server unit, e.g. 'AllTheTech').",
    },
    log: {
      type: "string",
      description: "Which log to read: 'latest' (default), 'debug', 'crash' (newest crash report), or 'all'. Only applies to the Prism Launcher path.",
    },
    filter: {
      type: "string",
      description: "Optional substring / regex to only show matching lines (e.g. 'ERROR', 'Exception', 'Failed to').",
    },
    tail: {
      type: "number",
      description: "Last N lines to show from a log file (default 100).",
    },
    dataDir: {
      type: "string",
      description: "Prism Launcher data dir override (default: auto-detect from known locations).",
    },
    server: {
      type: "string",
      description: "Server unit name for the fallback path (e.g. 'test'). Default: auto-detected from the repo's servers config.",
    },
    note: {
      type: "string",
      description: "Self-improvement: append this note as a RUN LOG entry to the tool's source file AND its paired skill (modules/nixos/minecraft-server/opencode/skill.md).",
    },
  },
  async execute(args: { modpack?: string; log?: string; filter?: string; tail?: number; dataDir?: string; server?: string; note?: string }) {
    if (args.note) {
      return appendRunLog(args.note);
    }
    if (!args.modpack) {
      return "mc-prism-log: provide a modpack name (e.g. 'AllTheTech').";
    }
    const tail = args.tail ?? 100;
    const dataDir = args.dataDir || findDataDir() || "";
    const instanceDir = dataDir ? findInstanceDir(dataDir, args.modpack) : null;

    if (!dataDir || !instanceDir) {
      return serverLogs(args.modpack, args.server, args.filter, tail);
    }

    const mcDir = join(instanceDir, ".minecraft");
    const logsDir = join(mcDir, "logs");
    const crashesDir = join(mcDir, "crash-reports");
    const which = args.log || "latest";

    const readLog = (name: string, path: string): string => {
      if (!existsSync(path)) return `${name}: not found at ${path}`;
      const lines = readFileSync(path, "utf-8").split("\n");
      let selected = lines;
      if (args.filter) {
        try {
          const re = new RegExp(args.filter);
          selected = lines.filter((l) => re.test(l));
        } catch {
          selected = lines.filter((l) => l.includes(args.filter));
        }
        if (selected.length === 0) {
          return `${name}: no lines matching '${args.filter}'`;
        }
      }
      const shown = selected.slice(-Math.max(tail, 1)).join("\n");
      const filtered = args.filter ? ` (${selected.length} matching '${args.filter}')` : "";
      return `${name}${filtered} — last ${Math.min(tail, selected.length)} of ${lines.length} lines:\n${shown}`;
    };

    const crash = newestFile(crashesDir);

    if (which === "crash") {
      if (!crash) return `mc-prism-log: no crash reports in ${crashesDir}`;
      return `Newest crash report: ${crash}\n${readFileSync(crash, "utf-8")}`;
    }

    if (which === "debug") {
      return readLog("debug.log", join(logsDir, "debug.log"));
    }

    if (which === "all") {
      const parts = [
        readLog("latest.log", join(logsDir, "latest.log")),
        readLog("debug.log", join(logsDir, "debug.log")),
      ];
      if (crash) {
        parts.push(`Newest crash report: ${crash}\n${readFileSync(crash, "utf-8")}`);
      }
      return parts.join("\n\n=====\n\n");
    }

    const latestPath = join(logsDir, "latest.log");
    if (!existsSync(latestPath)) {
      return `mc-prism-log: no latest.log at ${latestPath} (has the instance ever launched? crash: ${crash || "none"})`;
    }
    const out = readLog("latest.log", latestPath);
    if (crash) {
      return `${out}\n\nNote: a crash report exists: ${crash}`;
    }
    return out;
  },
};

// ## RUN LOG
// ### 2026-08-21
// Reading latest server log for performance analysis

// ## RUN LOG
// ### 2026-08-25
// checking Better Minecraft instance logs for errors on user request
