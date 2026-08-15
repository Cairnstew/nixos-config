import { execSync, spawn } from "node:child_process";
import { existsSync, readdirSync, readFileSync, appendFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

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

function hasCommand(bin: string): boolean {
  try {
    execSync(`command -v ${bin}`, { encoding: "utf-8" });
    return true;
  } catch {
    return false;
  }
}

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

function hasSystemdUnit(name: string): boolean {
  try {
    execSync(`systemctl list-unit-files ${name}.service --plain --no-legend 2>/dev/null`, { encoding: "utf-8" });
    return true;
  } catch {
    return false;
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

// ── Self-improvement ─────────────────────────────────────────────────────────
// Mirrors the researcher agent's SELF_IMPROVE + RUN LOG pattern, scoped to this
// tool's source. The runtime copy (~/.config/opencode/tools/) is a read-only
// store symlink; the SOURCE of truth is the repo file:
//   modules/nixos/minecraft-server/opencode/tools/mc-run.ts
// When the agent discovers a bug or improvement while using this tool it should
// edit that repo file (not the runtime copy) and append a RUN LOG entry. A
// `note` argument appends the entry programmatically.

const SOURCE_REL = join("modules", "nixos", "minecraft-server", "opencode", "tools", "mc-run.ts");
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
  return `mc-run: appended RUN LOG entry to ${out.join(" and ")}`;
}

// ── Launcher: Prism ──────────────────────────────────────────────────────────
interface Launched {
  kind: "prism" | "server";
  pid?: number; // process group leader (prism)
  unit?: string; // systemd unit (server)
  logDir?: string; // where latest.log lives
}

function prismLaunch(dataDir: string, instanceDir: string, modpack: string): Launched | string {
  const bin = ["prismlauncher", "PrismLauncher"].find((b) => hasCommand(b));
  if (!bin) {
    return `mc-run: found Prism instance '${modpack}' at ${instanceDir} but no 'prismlauncher' binary on PATH. Install Prism Launcher (my.programs.minecraft) or run the pack natively.`;
  }
  const dirArg = dataDir ? ["--dir", dataDir] : [];
  const args = [...dirArg, "--launch", modpack];
  const child = spawn(bin, args, {
    stdio: "ignore",
    detached: true, // own process group → can kill the whole group via -pid
    cwd: instanceDir,
    env: { ...process.env, PRISMLAUNCHER_DIR: dataDir },
  });
  child.unref();
  return {
    kind: "prism",
    pid: child.pid,
    logDir: join(instanceDir, ".minecraft", "logs"),
  };
}

function killPrism(pid?: number): void {
  if (!pid) return;
  try {
    process.kill(-pid, "SIGTERM");
  } catch {
    try {
      process.kill(pid, "SIGTERM");
    } catch {
      /* already gone */
    }
  }
}

// ── Launcher: native server ──────────────────────────────────────────────────
function serverLaunch(unitName: string): Launched | string {
  try {
    execSync(`systemctl start minecraft-server-${unitName}.service 2>&1`, { encoding: "utf-8", timeout: 30_000 });
    const dataDir = findServerLogDir();
    return { kind: "server", unit: unitName, logDir: dataDir ? join(dataDir, unitName, "logs") : undefined };
  } catch (e: any) {
    return `mc-run: failed to start minecraft-server-${unitName}.service:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
  }
}

function killServer(unit?: string): void {
  if (!unit) return;
  try {
    execSync(`systemctl stop minecraft-server-${unit}.service 2>/dev/null`, { encoding: "utf-8", timeout: 30_000 });
  } catch {
    /* ignore */
  }
}

// ── Monitor ──────────────────────────────────────────────────────────────────
function readLatest(path: string): string {
  try {
    return readFileSync(path, "utf-8");
  } catch {
    return "";
  }
}

function newestCrashReport(crashDir: string): string | null {
  if (!existsSync(crashDir)) return null;
  const files = readdirSync(crashDir).filter((f) => !f.endsWith(".gz")).map((f) => join(crashDir, f));
  if (files.length === 0) return null;
  files.sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs);
  return files[0];
}

const CRASH_RE = /Mod loading has failed|Fatal errors were detected|crash-reports|Skipping mod |Failed to load|Exception in thread/;

async function monitorLoop(
  modpack: string,
  launched: Launched,
  monitor: string,
  timeout: number
): Promise<string> {
  const crashDir = launched.logDir ? join(launched.logDir, "..", "crash-reports") : "";
  const logPath = launched.logDir ? join(launched.logDir, "latest.log") : "";
  const start = Date.now();
  let lastLen = 0;
  const waitMs = timeout > 0 ? timeout * 1000 : 300_000; // default 5 min if no timeout

  // Boot indicator regex.
  let target: RegExp;
  if (monitor === "boot") {
    target = launched.kind === "server"
      ? /Done \([0-9.]+s\)! For help, type "help"/i
      : /Sound engine started|Setting user:|Created: \d+x\d+ textures-atlas/i;
  } else if (monitor === "crash") {
    target = /$/; // never matches; only crash detection
  } else {
    try {
      target = new RegExp(monitor);
    } catch {
      target = new RegExp(monitor.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));
    }
  }

  while (Date.now() - start < waitMs) {
    const text = logPath ? readLatest(logPath) : "";
    const newChunk = text.slice(lastLen);
    lastLen = text.length;

    const crash = newestCrashReport(crashDir);
    if (crash) {
      return `mc-run: CRASH detected — ${crash}\n\n${readFileSync(crash, "utf-8").slice(0, 2000)}`;
    }
    if (CRASH_RE.test(newChunk)) {
      const tail = newChunk.split("\n").slice(-20).join("\n");
      return `mc-run: failure detected in log:\n${tail}`;
    }
    if (target.test(text)) {
      const tail = text.split("\n").slice(-25).join("\n");
      return `mc-run: indicator '${monitor}' reached for '${modpack}':\n${tail}`;
    }
    await sleep(2000);
  }
  const tail = (logPath ? readLatest(logPath) : "").split("\n").slice(-20).join("\n");
  return `mc-run: monitor timed out after ${Math.round((Date.now() - start) / 1000)}s for '${modpack}' (indicator '${monitor}' not seen).\nLast log:\n${tail}`;
}

// ── Top-level run ────────────────────────────────────────────────────────────
async function run(
  repo: string,
  modpack: string,
  server?: string,
  dataDir?: string,
  forceNative?: boolean,
  timeout = 0,
  monitor = ""
): Promise<string> {
  const prismDataDir = dataDir || findDataDir() || "";
  const instanceDir = prismDataDir ? findInstanceDir(prismDataDir, modpack) : null;
  const prismAvailable = (instanceDir !== null && hasCommand("prismlauncher")) || hasCommand("PrismLauncher");

  let launched: Launched | string | null = null;

  if (!forceNative && instanceDir && prismAvailable) {
    launched = prismLaunch(prismDataDir, instanceDir, modpack);
  } else if (!forceNative && prismDataDir && hasCommand("prismlauncher")) {
    const known = listInstances(prismDataDir).join(", ") || "(none)";
    launched = `mc-run: Prism Launcher is installed but has no instance for '${modpack}'. Known instances: ${known}.`;
  } else {
    const unitName = server || findServerForPack(repo, modpack);
    if (unitName && hasSystemdUnit(unitName)) {
      launched = serverLaunch(unitName);
    } else {
      try {
        const out = execSync(`nix build ${repo}#minecraft-modpack-${modpack} --no-link --print-out-paths 2>/dev/null`, {
          encoding: "utf-8",
          timeout: 600_000,
        }).trim().split("\n").pop();
        return `mc-run: no Prism Launcher and no running server on this host for '${modpack}'. Built client content (native fallback):
  nix build output: ${out}
To run natively, launch the pack with a raw launcher (e.g. Prism instance or a jar-based launcher) from ${out}/.minecraft.
Or enable the server: my.services.minecraftServer.servers.${server || "<name>"}.enable = true (see modules/nixos/minecraft-server/servers/).`;
      } catch (e: any) {
        return `mc-run: no Prism Launcher, no configured server, and building client content failed:\n${((e.stdout || "") + (e.stderr || "")).trim()}`;
      }
    }
  }

  if (typeof launched === "string") {
    // Prism installed but no matching instance → report and fall back to native.
    return launched;
  }

  // Plain launch with optional background timeout → return immediately.
  if (!monitor) {
    if (timeout > 0) {
      // Spawn a detached killer that closes the process group after `timeout`s.
      const kill = launched.kind === "prism"
        ? `kill -TERM -- -${launched.pid} 2>/dev/null; kill -TERM ${launched.pid} 2>/dev/null`
        : `systemctl stop minecraft-server-${launched.unit}.service 2>/dev/null`;
      const killer = spawn("sh", ["-c", `sleep ${timeout} && ${kill}`], { detached: true, stdio: "ignore" });
      killer.unref();
      return `mc-run: launched ${launched.kind} '${modpack}' — will auto-close after ${timeout}s. Logs: ${launched.logDir || "journald"}.`;
    }
    const base =
      launched.kind === "prism"
        ? `launched Prism Launcher instance '${modpack}' (data dir ${prismDataDir || "default"}). Logs: ${launched.logDir}`
        : `started minecraft-server-${launched.unit}.service. Logs: ${launched.logDir || "journalctl -u minecraft-server-" + launched.unit}`;
    return `mc-run: ${base}. Running indefinitely (pass timeout= to auto-close, or monitor= to watch and exit).`;
  }

  // Monitor mode: watch the log, then close.
  const result = await monitorLoop(modpack, launched, monitor, timeout);
  if (launched.kind === "prism") killPrism(launched.pid);
  else killServer(launched.unit);
  return `${result}\n\nmc-run: closed the ${launched.kind} instance.`;
}

export default {
  description:
    "Run a packwiz modpack from this repo (modules/nixos/minecraft-server/modpacks/<name>/). If Prism Launcher is available (binary + instance present), launch the instance. Otherwise fall back to a native run: start the dedicated minecraft-server unit for the pack if configured, else build the client content for a manual launch.\n\nOptions: timeout=<seconds> auto-closes the instance after N seconds (0 or omitted = run indefinitely). monitor=<'boot'|'crash'|regex> watches the log after launching and exits (closing the instance) as soon as the indicator is seen, a crash appears, or timeout elapses — use to confirm a pack boots or fails. Pass note=<text> to append a self-improvement RUN LOG entry to this tool's source file (modules/nixos/minecraft-server/opencode/tools/mc-run.ts) in the repo.",
  args: {
    modpack: {
      type: "string",
      description: "Modpack name (e.g. 'testModpack'). Maps to the Prism instance and/or the minecraft-server unit.",
    },
    server: {
      type: "string",
      description: "Server unit name for the native fallback (e.g. 'test'). Default: auto-detected from the repo's servers config.",
    },
    dataDir: {
      type: "string",
      description: "Prism Launcher data dir override (default: auto-detect from known locations).",
    },
    forceNative: {
      type: "boolean",
      description: "Skip Prism Launcher and use the native path (start server / build client content).",
    },
    timeout: {
      type: "number",
      description: "Seconds before the instance is closed automatically. 0 or omitted = run indefinitely.",
    },
    monitor: {
      type: "string",
      description: "Watch the log after launching and exit (closing the instance) when seen: 'boot' (server 'Done (...)' / client main menu), 'crash' (early-exit on any crash), or a custom regex. Also exits on any crash and on timeout.",
    },
    note: {
      type: "string",
      description: "Self-improvement: append this note as a RUN LOG entry to the tool's source file AND its paired skill (modules/nixos/minecraft-server/opencode/skill.md).",
    },
  },
  async execute(args: { modpack?: string; server?: string; dataDir?: string; forceNative?: boolean; timeout?: number; monitor?: string; note?: string }) {
    if (args.note) {
      return appendRunLog(args.note);
    }
    if (!args.modpack) {
      return "mc-run: provide a modpack name (e.g. 'testModpack').";
    }
    return run(repoRoot(), args.modpack, args.server, args.dataDir, args.forceNative, args.timeout || 0, args.monitor || "");
  },
};
