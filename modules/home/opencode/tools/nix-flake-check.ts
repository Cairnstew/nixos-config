import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { hostname } from "node:os";

function bytesToGb(bytes: number): number {
  return Math.round(bytes / (1024 * 1024 * 1024) * 10) / 10;
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
    const total = meminfo.match(/^MemTotal:\s+(\d+)\s+kB/im);
    const free = meminfo.match(/^MemFree:\s+(\d+)\s+kB/im);
    if (total && free) return (Number(total[1]) * 0.2 + Number(free[1]) * 0.8) * 1024;
  } catch {
    // no /proc/meminfo
  }
  return 4 * 1024 ** 3; // 4 GiB fallback
}

function pickLimit(): number {
  const cgroupLimit = readCgroupLimit();
  const memAvail = readMemAvailable();

  const raw = Math.min(
    memAvail,
    cgroupLimit ?? Infinity,
  );

  // Leave 1.5 GiB for sshd/tailscaled/journald, then use 85% of the rest.
  // The old 75%-of-free value still let a 10.5G `nix` process OOM the 13G
  // server when the command ran from a raw shell.
  const headroom = 1.5 * 1024 ** 3;
  const usable = Math.max(raw - headroom, 1024 ** 3);
  const bytes = Math.min(Math.round(usable * 0.85), 11 * 1024 ** 3);

  // never exceed cgroup limit if one is set
  return cgroupLimit !== null ? Math.min(bytes, Math.round(cgroupLimit * 0.9)) : bytes;
}

function memoryLimitArg(bytes: number): string {
  const safe = Math.max(512 * 1024 * 1024, bytes);
  // MemorySwapMax=0 makes the eval die at MemoryMax instead of thrashing
  // compressed zram for minutes — a killed eval is recoverable, a wedged
  // host is not.
  return `systemd-run --user --scope -p MemoryMax=${safe} -p MemoryHigh=${safe} -p MemorySwapMax=0 --same-dir`;
}

export default {
  description: "Run 'nix flake check --no-build' to validate the Nix flake configuration. Catches evaluation errors, assertion failures, and missing options before deployment.",
  args: {
    allowWarnings: {
      type: "boolean",
      description: "If true, treat warnings as success. Default: false (warnings count as failure).",
    },
    memoryLimitGB: {
      type: "number",
      description: "Hard memory limit in GB via cgroup. When omitted, auto-detects available RAM (leaves 1.5G for system daemons, uses 85% of the rest, capped at 11G).",
    },
  },
  async execute(args: { allowWarnings?: boolean; memoryLimitGB?: number }) {
    const avail = readMemAvailable();
    if (avail < 3 * 1024 ** 3) {
      return `✗ refusing to run nix flake check: only ${bytesToGb(avail)}G RAM available. `
        + `Free memory first (another nix build / opencode team?) or run the check on the desktop.`;
    }

    const limitBytes = args.memoryLimitGB
      ? Math.round(args.memoryLimitGB * 1024 ** 3)
      : pickLimit();
    const limitGb = bytesToGb(limitBytes);
    const prefix = memoryLimitArg(limitBytes);
    const cmd = `${prefix} nix flake check --no-build 2>&1`;
    const serverNote = hostname() === "server"
      ? "\n\nNOTE: this host has 13 GiB RAM — prefer full flake checks on the desktop. "
        + "Scope to one host with `nix derivation show .#checks.x86_64-linux.build-server`."
      : "";

    try {
      const flakeDir = process.env.PWD || ".";

      const out = execSync(cmd, {
        encoding: "utf-8",
        timeout: 120_000,
        cwd: flakeDir,
        maxBuffer: 10 * 1024 * 1024,
      });

      return `✓ nix flake check passed (mem limit: ${limitGb}G)\n\n${out}`;
    } catch (e: any) {
      const stderr = e.stderr || "";
      const stdout = e.stdout || "";
      const combined = (stdout + stderr).trim();

      if (combined.includes("MemoryMax") || combined.includes("cgroup")) {
        return `✗ nix flake check terminated — hit ~${limitGb}G memory limit. Increase with memoryLimitGB arg.${serverNote}\n\n${combined}`;
      }

      if (args.allowWarnings) {
        const hasErrors = combined.includes("error:") || combined.includes("Error:");
        if (!hasErrors) {
          return `✓ nix flake check passed (with warnings)\n\n${combined}`;
        }
      }

      return `✗ nix flake check failed${serverNote}\n\n${combined}`;
    }
  },
};
