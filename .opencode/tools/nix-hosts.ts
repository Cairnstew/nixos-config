import { tool } from "@opencode-ai/plugin";
import { execSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";

interface HostInfo {
  name: string;
  type: "nixos" | "darwin" | "home";
  hostname?: string;
  platform?: string;
  sshTarget?: string;
  profiles?: {
    system: string[];
    home: string[];
  };
  configPath?: string;
}

function tryEval(
  worktree: string,
  attr: string
): string | null {
  try {
    const out = execSync(`nix eval --json --no-write-lock-file "path:${worktree}#${attr}" 2>/dev/null`, {
      cwd: worktree,
      encoding: "utf-8",
      timeout: 30_000,
    });
    return out.trim();
  } catch {
    return null;
  }
}

function tryEvalRaw(
  worktree: string,
  attr: string
): string | null {
  try {
    const out = execSync(`nix eval --raw --no-write-lock-file "path:${worktree}#${attr}" 2>/dev/null`, {
      cwd: worktree,
      encoding: "utf-8",
      timeout: 30_000,
    });
    return out.trim();
  } catch {
    return null;
  }
}

function listHosts(
  worktree: string,
  category: string
): string[] {
  try {
    const out = execSync(
      `nix eval --json --no-write-lock-file --apply 'x: builtins.attrNames x' "path:${worktree}#${category}" 2>/dev/null`,
      { cwd: worktree, encoding: "utf-8", timeout: 30_000 }
    );
    return JSON.parse(out.trim()) as string[];
  } catch {
    return [];
  }
}

function readHostConfig(worktree: string, type: string, host: string): HostInfo | null {
  const dir = type === "darwin" ? "darwin" : type === "home" ? "home" : "nixos";
  const configPaths = [
    join(worktree, "configurations", dir, host, "default.nix"),
    join(worktree, "configurations", dir, `${host}.nix`),
  ];

  for (const configPath of configPaths) {
    try {
      const content = readFileSync(configPath, "utf-8");
      const hostname = content.match(/networking\.hostName\s*=\s*"([^"]+)"/)?.[1];
      const sshTarget = content.match(/nixos-unified\.sshTarget\s*=\s*"([^"]+)"/)?.[1];
      const platform = content.match(/nixpkgs\.hostPlatform\s*=\s*"([^"]+)"/)?.[1];

      const systemProfiles: string[] = [];
      const homeProfiles: string[] = [];

      const profileRegex = /my\.(home)?Profiles\.([a-zA-Z-]+(?:\.\w+)*)\s*\.\s*enable\s*=\s*true/g;
      let match;
      while ((match = profileRegex.exec(content)) !== null) {
        if (match[1] === "home") {
          homeProfiles.push(match[2]);
        } else {
          systemProfiles.push(match[2]);
        }
      }

      return {
        name: host,
        type: type as HostInfo["type"],
        hostname: hostname,
        platform: platform || (dir === "darwin" ? "aarch64-darwin" : undefined),
        sshTarget: sshTarget,
        profiles: {
          system: systemProfiles,
          home: homeProfiles,
        },
        configPath,
      };
    } catch {
      continue;
    }
  }

  return null;
}

export default tool({
  description:
    "List all configured NixOS/darwin/home hosts with their hostname, platform, SSH target, enabled profiles, and config file path. Use this to discover available hosts and understand their current configuration before making changes.",

  args: {
    host: tool.schema
      .string()
      .optional()
      .describe("Filter to a specific hostname (e.g. 'laptop', 'server')."),
    type: tool.schema
      .string()
      .optional()
      .default("all")
      .describe("Filter by configuration type: 'nixos', 'darwin', 'home', or 'all'."),
  },

  async execute(args, context) {
    const { host, type } = args;
    const worktree = context.worktree || context.directory;
    const hosts: HostInfo[] = [];

    const typesToCheck = type === "all" ? ["nixos", "darwin", "home"] as const : [type as "nixos" | "darwin" | "home"];

    for (const t of typesToCheck) {
      const category = t === "nixos"
        ? "nixosConfigurations"
        : t === "darwin"
          ? "darwinConfigurations"
          : "homeConfigurations";

      const names = listHosts(worktree, category);

      for (const name of names) {
        if (host && !name.includes(host)) continue;
        const info = readHostConfig(worktree, t, name);
        if (info) hosts.push(info);
      }
    }

    if (hosts.length === 0) {
      const filterMsg = host ? ` matching "${host}"` : "";
      return `No hosts found${filterMsg}. Ensure they are staged with 'git add' (flakes only see committed/staged files).`;
    }

    const lines: string[] = [
      `Found ${hosts.length} host(s):`,
      "",
    ];

    for (const h of hosts) {
      lines.push(`  [${h.type.toUpperCase()}] ${h.name}`);
      if (h.hostname) lines.push(`    hostname:   ${h.hostname}`);
      if (h.platform) lines.push(`    platform:   ${h.platform}`);
      if (h.sshTarget) lines.push(`    ssh:        ${h.sshTarget}`);
      if (h.profiles?.system.length) lines.push(`    profiles:   ${h.profiles.system.join(", ")}`);
      if (h.profiles?.home.length) lines.push(`    home:       ${h.profiles.home.join(", ")}`);
      lines.push(`    config:     ${h.configPath}`);
      lines.push("");
    }

    return lines.join("\n");
  },
});
