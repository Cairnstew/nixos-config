import { tool } from "@opencode-ai/plugin";
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join } from "node:path";

interface UpstreamMeta {
  repo?: string;
  space?: string;
  mode?: string; // 'wrapped' | 'vendored' | 'input' — see modules/AGENT.md §4
  flakeInput?: string;
}

interface ModuleMeta {
  name: string;
  description: string;
  category: string;
  tags: string[];
  provides: string[];
  expects: string[];
  complexity: string;
  tested: boolean;
  maintainer?: string;
  homepage?: string;
  upstream?: UpstreamMeta;
  path: string;
  relPath: string;
}

const CATEGORIES = ["nixos", "home", "darwin", "flake-parts"] as const;

function parseMetaNix(content: string): Partial<ModuleMeta> {
  const meta: Partial<ModuleMeta> = {};

  const str = (key: string): string | undefined => {
    const m = content.match(new RegExp(`${key}\\s*=\\s*"([^"]*)"`));
    return m?.[1];
  };

  const bool = (key: string): boolean | undefined => {
    const m = content.match(new RegExp(`${key}\\s*=\\s*(true|false)`));
    return m ? m[1] === "true" : undefined;
  };

  const list = (key: string): string[] => {
    const m = content.match(new RegExp(`${key}\\s*=\\s*\\[([^\\]]*)\\]`));
    if (!m) return [];
    return m[1]
      .split("\n")
      .map((s) => s.trim())
      .filter((s) => s && !s.startsWith("#"))
      .map((s) => s.replace(/^"|"$/g, ""));
  };

  meta.name = str("name");
  meta.description = str("description");
  meta.category = str("category");
  meta.tags = list("tags");
  meta.provides = list("provides");
  meta.expects = list("expects");
  meta.complexity = str("complexity") || "simple";
  meta.tested = bool("tested") ?? false;
  meta.maintainer = str("maintainer");
  meta.homepage = str("homepage");

  // upstream block: `upstream = { repo = "..."; mode = "..."; space = "..."; flakeInput = "..."; };`
  const up = content.match(/upstream\s*=\s*\{(.*?)\n\s*\};/s);
  if (up) {
    const upStr = (key: string): string | undefined => {
      const m = up[1].match(new RegExp(`${key}\\s*=\\s*"([^"]*)"`));
      return m?.[1];
    };
    const u: UpstreamMeta = {};
    const repo = upStr("repo");
    const mode = upStr("mode");
    const space = upStr("space");
    const flakeInput = upStr("flakeInput");
    if (repo || mode || space || flakeInput) {
      u.repo = repo;
      u.mode = mode;
      u.space = space;
      u.flakeInput = flakeInput;
      meta.upstream = u;
    }
  }

  return meta;
}

// Render the upstream line for one module, mode-aware (matches the finalized
// per-mode matrix in the space-discovery design; modes in modules/AGENT.md §4).
function renderUpstream(u: UpstreamMeta): string {
  const repo = u.repo ? `repo=${u.repo}` : "";
  const flake = u.flakeInput ? `flakeInput=${u.flakeInput}` : "";
  switch (u.mode) {
    case "vendored":
      return `upstream: VENDORED space=${u.space ?? "(missing)"} — do NOT edit locally; re-vendor per modules/home/opencode/FORK.md`;
    case "input":
      return `upstream: (input) ${repo} — work in the upstream repo (no local copy to edit); no space registered`;
    case "wrapped":
    default:
      if (u.space) {
        return `upstream: space=${u.space} (wrapped)${[repo, flake].filter(Boolean).join(", ") ? ` [${[repo, flake].filter(Boolean).join(", ")}]` : ""}`;
      }
      return `upstream: (wrapped) ${[repo, flake].filter(Boolean).join(", ")} — no space registered; work upstream directly`;
  }
}

function discoverModules(worktree: string, category: string): ModuleMeta[] {
  const modulesDir = join(worktree, "modules", category);
  let entries: string[];

  try {
    entries = readdirSync(modulesDir, { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .map((d) => d.name);
  } catch {
    return [];
  }

  const modules: ModuleMeta[] = [];

  for (const entry of entries) {
    const metaPath = join(modulesDir, entry, "meta.nix");
    if (!existsSync(metaPath)) continue;

    try {
      const content = readFileSync(metaPath, "utf-8");
      const meta = parseMetaNix(content);
      modules.push({
        name: meta.name || entry,
        description: meta.description || "(no description)",
        category: meta.category || category,
        tags: meta.tags || [],
        provides: meta.provides || [],
        expects: meta.expects || [],
        complexity: meta.complexity || "simple",
        tested: meta.tested || false,
        maintainer: meta.maintainer,
        homepage: meta.homepage,
        upstream: meta.upstream,
        path: metaPath,
        relPath: `modules/${category}/${entry}/meta.nix`,
      });
    } catch {
      modules.push({
        name: entry,
        description: "(failed to parse meta.nix)",
        category,
        tags: [],
        provides: [],
        expects: [],
        complexity: "unknown",
        tested: false,
        path: metaPath,
        relPath: `modules/${category}/${entry}/meta.nix`,
      });
    }
  }

  return modules;
}

export default tool({
  description:
    "List all NixOS/home/darwin/flake-parts modules with their metadata from meta.nix files. Returns name, description, category, what options they provide, their complexity, test status, and — when the module wraps/vendors/consumes an external repo — an 'upstream' line naming the ensemble space to develop it in (or noting no space is registered). Use this to discover what modules exist and what they do before writing configuration. ALWAYS check the upstream line before editing a module: if it names a space, implementation changes belong upstream via team_spawn(space=...), not in this repo.",

  args: {
    category: tool.schema
      .string()
      .optional()
      .default("all")
      .describe("Filter by module category: 'nixos', 'home', 'darwin', 'flake-parts', or 'all'."),
    query: tool.schema
      .string()
      .optional()
      .describe("Search term to filter by name, description, tags, or provided options."),
    filter: tool.schema
      .string()
      .optional()
      .describe("Shortcut filter: 'untested' (modules without tests), 'tested' (modules with tests), 'complex' (complex modules)."),
  },

  async execute(args, context) {
    const { category, query, filter } = args;
    const worktree = context.worktree || context.directory;
    let allModules: ModuleMeta[] = [];

    const cats = category === "all" ? [...CATEGORIES] : [category as string];
    for (const cat of cats) {
      if (CATEGORIES.includes(cat as typeof CATEGORIES[number])) {
        allModules.push(...discoverModules(worktree, cat));
      }
    }

    let filtered = allModules;

    if (filter === "untested") {
      filtered = filtered.filter((m) => !m.tested);
    } else if (filter === "tested") {
      filtered = filtered.filter((m) => m.tested);
    } else if (filter === "complex") {
      filtered = filtered.filter((m) => m.complexity === "complex");
    }

    if (query) {
      const q = query.toLowerCase();
      filtered = filtered.filter((m) => {
        const haystack = [m.name, m.description, ...m.tags, ...m.provides, ...m.expects]
          .join(" ")
          .toLowerCase();
        return haystack.includes(q);
      });
    }

    if (filtered.length === 0) {
      const parts: string[] = [];
      if (category !== "all") parts.push(`in "${category}"`);
      if (query) parts.push(`matching "${query}"`);
      if (filter) parts.push(`filter "${filter}"`);
      return `No modules found${parts.length > 0 ? ` ${parts.join(" ")}` : ""}.`;
    }

    const lines: string[] = [
      `Found ${filtered.length} module(s):`,
      "",
    ];

    const sorted = [...filtered].sort((a, b) => {
      const catOrder = CATEGORIES.indexOf(a.category as typeof CATEGORIES[number]) -
        CATEGORIES.indexOf(b.category as typeof CATEGORIES[number]);
      return catOrder !== 0 ? catOrder : a.name.localeCompare(b.name);
    });

    for (const m of sorted) {
      const tags = m.tags.length > 0 ? ` [${m.tags.slice(0, 4).join(", ")}${m.tags.length > 4 ? "..." : ""}]` : "";
      const tested = m.tested ? "✓" : "✗";
      lines.push(`  ${tested} ${m.name.padEnd(25)} ${m.category.padEnd(12)} ${m.complexity.padEnd(8)}${tags}`);
      lines.push(`     provides: ${m.provides.join(", ") || "(none)"}`);
      if (m.upstream) lines.push(`     ${renderUpstream(m.upstream)}`);
      if (m.description) lines.push(`     ${m.description}`);
      lines.push(`     ${m.relPath}`);
      lines.push("");
    }

    const total = allModules.length;
    const testedCount = allModules.filter((m) => m.tested).length;
    const complexCount = allModules.filter((m) => m.complexity === "complex").length;
    lines.push(`Summary: ${total} total, ${testedCount} tested, ${complexCount} complex.`);

    return lines.join("\n");
  },
});
