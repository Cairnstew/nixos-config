import { tool } from "@opencode-ai/plugin";
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join } from "node:path";

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

  return meta;
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
    "List all NixOS/home/darwin/flake-parts modules with their metadata from meta.nix files. Returns name, description, category, what options they provide, their complexity, and test status. Use this to discover what modules exist and what they do before writing configuration.",

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
