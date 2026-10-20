import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";

const GiB = 1024 ** 3;

function bytesToGb(bytes: number): number {
  return Math.round(bytes / GiB * 10) / 10;
}

function readCgroupLimit(): number | null {
  try {
    const raw = readFileSync("/sys/fs/cgroup/memory.max", "utf-8").trim();
    const n = Number(raw);
    if (Number.isFinite(n) && n > 0) return n;
  } catch {
    // not in a cgroup v2 with a limit
  }
  return null;
}

function readMemAvailable(): number {
  try {
    const meminfo = readFileSync("/proc/meminfo", "utf-8");
    const m = meminfo.match(/^MemAvailable:\s+(\d+)\s+kB/im);
    if (m) return Number(m[1]) * 1024;
  } catch {
    // no /proc/meminfo
  }
  return 4 * GiB; // 4 GiB fallback
}

function pickLimit(): number {
  const raw = Math.min(readMemAvailable(), readCgroupLimit() ?? Infinity);
  // 1 GiB headroom for sshd/tailscaled/journald, then 80% of the rest.
  const usable = Math.max(raw - GiB, GiB);
  return Math.min(Math.round(usable * 0.8), 10 * GiB);
}

function memoryLimitArg(bytes: number): string {
  const safe = Math.max(512 * 1024 * 1024, bytes);
  // MemorySwapMax=0: die at the cap instead of thrashing compressed zram.
  return `systemd-run --user --scope -p MemoryMax=${safe} -p MemoryHigh=${safe} -p MemorySwapMax=0 --same-dir`;
}

export default {
  description: "Safely evaluate Nix expressions or check flake outputs. Use this to validate Nix syntax, check attribute paths, and debug evaluation failures before committing changes. Runs under a cgroup memory cap so a runaway evaluation cannot OOM a remote host.",
  args: {
    attr: {
      type: "string",
      description: "Flake output attribute path to evaluate (e.g. 'nixosConfigurations.laptop', 'packages.x86_64-linux.ventoy-deploy'). Mutually exclusive with 'expr'.",
    },
    expr: {
      type: "string",
      description: "Raw Nix expression to evaluate. Mutually exclusive with 'attr'.",
    },
    raw: {
      type: "boolean",
      description: "If true, return raw string output instead of JSON. Useful for non-JSON results.",
    },
    memoryLimitGB: {
      type: "number",
      description: "Hard memory limit in GB via cgroup. When omitted, leaves 1G for system daemons and uses 80% of the rest (capped at 10G).",
    },
  },
  async execute(args: { attr?: string; expr?: string; raw?: boolean; memoryLimitGB?: number }) {
    const avail = readMemAvailable();
    if (avail < 2 * GiB) {
      return `nix-eval: refusing to run — only ${bytesToGb(avail)}G RAM available. Free memory first or run the evaluation on the desktop.`;
    }

    const limit = args.memoryLimitGB
      ? Math.round(args.memoryLimitGB * GiB)
      : pickLimit();
    const prefix = memoryLimitArg(limit);

    try {
      const flakeDir = process.env.PWD || ".";

      if (!args.attr && !args.expr) {
        return "nix-eval: Provide either 'attr' (flake attribute path) or 'expr' (raw Nix expression).";
      }

      let cmd: string;
      let isJson = false;

      if (args.attr) {
        cmd = `${prefix} nix eval ${flakeDir}#${args.attr} --json 2>&1`;
        isJson = !args.raw;
      } else {
        // Sanity check the expression to avoid dangerous operations
        const expr = args.expr!;
        const dangerous = ["builtins.readFile", "builtins.readDir", "builtins.fetch", "import <", "abort", "throw", "builtins.derivation"];
        for (const pattern of dangerous) {
          if (expr.includes(pattern)) {
            return `nix-eval: Expression contains potentially dangerous operation (${pattern}). For safety, only pure evaluation is allowed.`;
          }
        }
        cmd = `${prefix} nix eval --json --expr '${expr.replace(/'/g, "'\\''")}' 2>&1`;
        isJson = !args.raw;
      }

      const out = execSync(cmd, {
        encoding: "utf-8",
        timeout: 60_000,
        cwd: flakeDir,
        maxBuffer: 10 * 1024 * 1024,
      });

      if (isJson) {
        try {
          return JSON.stringify(JSON.parse(out), null, 2);
        } catch {
          return out;
        }
      }

      return out;
    } catch (e: any) {
      const stderr = e.stderr || "";
      const stdout = e.stdout || "";
      const combined = (stdout + stderr).trim();

      if (e.status === 137 || combined.includes("MemoryMax") || combined.includes("cgroup")) {
        return `nix-eval: terminated by the ${bytesToGb(limit)}G memory cap — scope the expression down or raise memoryLimitGB.\n\n${combined}`;
      }

      return `nix-eval failed:\n${combined}`;
    }
  },
};
