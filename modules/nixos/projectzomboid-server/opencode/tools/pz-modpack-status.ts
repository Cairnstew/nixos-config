import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { execSync } from "node:child_process";

const pzRel = join("modules", "nixos", "projectzomboid-server");

function repoRoot(): string {
  try {
    return execSync("git rev-parse --show-toplevel 2>/dev/null", { encoding: "utf-8" }).trim() || process.env.PWD || ".";
  } catch {
    return process.env.PWD || ".";
  }
}

function listCatalog(dir: string, repo: string): string {
  const path = join(repo, pzRel, dir);
  try {
    return readdirSync(path).filter((n) => n.endsWith(".nix") && n !== "default.nix").join(", ");
  } catch {
    return "(none)";
  }
}

/** Extract the declared Steam Workshop item IDs from a modpack/server .nix file. */
function workshopIds(file: string): string[] {
  const src = readFileSync(file, "utf-8");
  const ids: string[] = [];
  for (const m of src.matchAll(/id\s*=\s*"(\d+)"/g)) ids.push(m[1]);
  return [...new Set(ids)];
}

export default {
  description:
    "Inspect Project Zomboid modpack/servers in this repo (modules/nixos/projectzomboid-server/): list the named modpacks and servers and report the Steam Workshop item IDs each declares. Read-only status tool.",
  args: {
    modpack: {
      type: "string",
      description: "Optional modpack name to detail (e.g. 'vanilla-plus'). Omit to summarize all.",
    },
  },
  async execute(args: { modpack?: string }) {
    const repo = repoRoot();
    const modpacksDir = join(repo, pzRel, "modpacks");
    const serversDir = join(repo, pzRel, "servers");

    const lines: string[] = [];
    lines.push(`Project Zomboid module: ${pzRel}`);
    lines.push(`Modpacks: ${listCatalog("modpacks", repo)}`);
    lines.push(`Servers:  ${listCatalog("servers", repo)}`);

    if (args.modpack) {
      const file = join(modpacksDir, `${args.modpack}.nix`);
      if (!existsSync(file)) {
        return [`No modpack '${args.modpack}'.`, ...lines].join("\n");
      }
      const ids = workshopIds(file);
      lines.push(`\nModpack '${args.modpack}':`);
      lines.push(`  Workshop item IDs (${ids.length}): ${ids.join(", ") || "(none)"}`);
    } else {
      // Summary: per-pack workshop counts.
      for (const f of readdirSync(modpacksDir).filter((n) => n.endsWith(".nix") && n !== "default.nix")) {
        const ids = workshopIds(join(modpacksDir, f));
        lines.push(`  - ${f.replace(/\.nix$/, "")}: ${ids.length} workshop item(s) — ${ids.slice(0, 4).join(", ")}${ids.length > 4 ? "…" : ""}`);
      }
    }
    return lines.join("\n");
  },
};
