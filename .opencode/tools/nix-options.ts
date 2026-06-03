import { tool } from "@opencode-ai/plugin";
import { readFileSync } from "node:fs";
import { join } from "node:path";

interface OptionEntry {
  option: string;
  type: string;
  default: string;
  description: string;
  section: string;
}

const heatmapPath = "HEATMAP.md";

function parseOptionsTable(text: string, sectionName: string): OptionEntry[] {
  const lines = text.split("\n");
  const entries: OptionEntry[] = [];
  let inTable = false;
  let headerRow = 0;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.startsWith("| Option |")) {
      inTable = true;
      headerRow = i;
      continue;
    }
    if (inTable && line.startsWith("|")) {
      const cells = line
        .split("|")
        .slice(1, -1)
        .map((c) => c.trim().replace(/`/g, ""));
      if (cells.length >= 4 && !line.includes("---")) {
        entries.push({
          option: cells[0],
          type: cells[1] || "",
          default: cells[2] || "",
          description: cells.slice(3).join(" | ") || "",
          section: sectionName,
        });
      }
    } else if (inTable && !line.startsWith("|")) {
      inTable = false;
    }
  }

  return entries;
}

function getAllOptions(worktree: string): OptionEntry[] {
  try {
    const md = readFileSync(join(worktree, heatmapPath), "utf-8");
    const sections = md.split(/(?=^## )/m);

    const all: OptionEntry[] = [];
    for (const section of sections) {
      const header = section.match(/^## (.*)/m)?.[1] || "Unknown";
      all.push(...parseOptionsTable(section, header));
    }
    return all;
  } catch {
    return [];
  }
}

function scoreMatch(option: string, query: string): number {
  const q = query.toLowerCase();
  const o = option.toLowerCase();
  if (o === q) return 100;
  if (o.endsWith(q)) return 80;
  if (o.includes(q)) return 60;
  const qParts = q.split(/[.\s_-]/);
  const oParts = o.split(".");
  const matchedParts = qParts.filter((p) => oParts.some((op) => op.includes(p)));
  return qParts.length > 0 ? (matchedParts.length / qParts.length) * 40 : 0;
}

export default tool({
  description:
    "Search the my.* option registry from HEATMAP.md. Returns matching options with type, default value, and description. Use this to discover available configuration options instead of guessing option paths or searching documentation manually.",

  args: {
    query: tool.schema
      .string()
      .describe(
        "Search term. Matches against option name, section, and description. Examples: 'tailscale', 'docker.enable', 'gpu', 'steam.remotePlay'."
      ),
    namespace: tool.schema
      .string()
      .optional()
      .default("")
      .describe(
        "Filter by namespace prefix (e.g. 'my.profiles', 'my.services', 'my.programs', 'my.virtualisation'). Use empty string for all."
      ),
  },

  async execute(args, context) {
    const { query, namespace } = args;
    const worktree = context.worktree || context.directory;
    const all = getAllOptions(worktree);

    if (all.length === 0) {
      return "Could not read HEATMAP.md. Ensure the file exists at the repo root.";
    }

    let filtered = all;

    if (namespace) {
      const ns = namespace.endsWith(".") ? namespace : namespace + ".";
      filtered = filtered.filter((e) => e.option.startsWith(ns));
    }

    if (query.trim()) {
      filtered = filtered
        .map((e) => ({
          ...e,
          _score: Math.max(
            scoreMatch(e.option, query),
            scoreMatch(e.description, query),
            scoreMatch(e.section, query)
          ),
        }))
        .filter((e) => e._score > 0)
        .sort((a, b) => b._score - a._score);
    }

    if (filtered.length === 0) {
      return query.trim()
        ? `No options matched "${query}"${namespace ? ` under "${namespace}"` : ""}.`
        : `No options found${namespace ? ` under "${namespace}"` : ""}.`;
    }

    const lines: string[] = [
      `Found ${filtered.length} matching option(s):`,
      "",
    ];

    const show = filtered.slice(0, 40);
    const maxOption = Math.max(...show.map((e) => e.option.length));
    const maxType = Math.max(...show.map((e) => e.type.length), 4);
    const maxDefault = Math.max(...show.map((e) => e.default.length), 7);

    const header = [
      "Option".padEnd(maxOption),
      " | Type".padEnd(maxType + 3),
      " | Default".padEnd(maxDefault + 3),
      " | Description",
    ].join("");

    lines.push(header);
    lines.push("-".repeat(header.length));

    for (const entry of show) {
      lines.push(
        [
          entry.option.padEnd(maxOption),
          " | ",
          entry.type.padEnd(maxType),
          " | ",
          entry.default.padEnd(maxDefault),
          " | ",
          entry.description,
        ].join("")
      );
    }

    if (filtered.length > 40) {
      lines.push("", `(${filtered.length - 40} more results — refine your query)`);
    }

    lines.push(
      "",
      `Queried namespace: "${namespace || "(all)"}"`,
      `Source: ${heatmapPath}`
    );

    return lines.join("\n");
  },
});
