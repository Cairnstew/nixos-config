import { execSync } from "node:child_process";

interface HostEntry {
  type: string;
  hostname: string;
  platform: string;
  ssh: string | null;
  config: string;
  profiles: string[];
}

export default {
  description: "List all configured NixOS/darwin/home hosts with their hostname, platform, SSH target, enabled profiles, and config file path. Use this to discover available hosts and understand their current configuration before making changes.",
  args: {
    host: {
      type: "string",
      description: "Filter to a specific hostname (e.g. 'laptop', 'server')",
    },
    type: {
      type: "string",
      description: "Filter by configuration type: 'nixos', 'darwin', 'home', or 'all'",
    },
  },
  async execute(args: { host?: string; type?: string }) {
    try {
      const flakeDir = process.env.PWD || ".";
      let cmd = `nix run ${flakeDir}#test list -- 2>/dev/null`;

      const out = execSync(cmd, {
        encoding: "utf-8",
        timeout: 60_000,
        cwd: flakeDir,
      });

      let hosts: HostEntry[] = [];
      const lines = out.trim().split("\n");
      let currentHost: Partial<HostEntry> | null = null;

      for (const line of lines) {
        const nixosMatch = line.match(/^\[\s*([A-Z]+)\s*\]\s+(\S+)$/);
        if (nixosMatch) {
          if (currentHost?.hostname) {
            hosts.push(currentHost as HostEntry);
          }
          currentHost = {
            type: nixosMatch[1],
            hostname: nixosMatch[2],
            profiles: [],
          };
          continue;
        }

        const detailMatch = line.match(/^\s{2}(\S+):\s+(.+)$/);
        if (detailMatch && currentHost) {
          const key = detailMatch[1];
          const value = detailMatch[2];
          if (key === "hostname") currentHost.hostname = value;
          else if (key === "platform") currentHost.platform = value;
          else if (key === "ssh") currentHost.ssh = value;
          else if (key === "config") currentHost.config = value;
          else if (key === "profiles" && value) {
            currentHost.profiles = value.split(", ").filter(Boolean);
          }
        }
      }

      if (currentHost?.hostname) {
        hosts.push(currentHost as HostEntry);
      }

      // If no structured output, fall back to nix eval on configs
      if (hosts.length === 0) {
        const evalCmd = `nix eval ${flakeDir}#nixosConfigurations --apply 'x: builtins.attrNames x' --json 2>/dev/null`;
        try {
          const evalOut = execSync(evalCmd, {
            encoding: "utf-8",
            timeout: 30_000,
          });
          const names: string[] = JSON.parse(evalOut);
          hosts = names.map((name) => ({
            type: "NIXOS",
            hostname: name,
            platform: "unknown",
            ssh: null,
            config: `configurations/nixos/${name}/default.nix`,
            profiles: [],
          }));
        } catch {
          return `nix-hosts: Could not enumerate hosts.\nRaw output:\n${out}`;
        }
      }

      // Apply filters
      if (args.type && args.type !== "all") {
        hosts = hosts.filter((h) => h.type.toLowerCase() === args.type!.toLowerCase());
      }
      if (args.host) {
        hosts = hosts.filter((h) => h.hostname.toLowerCase().includes(args.host!.toLowerCase()));
      }

      if (hosts.length === 0) {
        return "nix-hosts: No hosts found matching the given filters.";
      }

      const formatted = hosts.map((h) => {
        const parts = [`[${h.type}] ${h.hostname}`];
        if (h.platform) parts.push(`  platform: ${h.platform}`);
        if (h.ssh) parts.push(`  ssh: ${h.ssh}`);
        if (h.config) parts.push(`  config: ${h.config}`);
        if (h.profiles && h.profiles.length > 0) {
          parts.push(`  profiles: ${h.profiles.join(", ")}`);
        }
        return parts.join("\n");
      });

      return formatted.join("\n\n");
    } catch (e: any) {
      const stderr = e.stderr || "";
      return `nix-hosts failed:\n${stderr}`;
    }
  },
};
