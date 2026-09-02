// comfyui-workspace — get/set the active ComfyUI workflow (the "workspace")
// for this opencode project. Pairs with the comfyui-workspace PLUGIN
// (plugin/workspace.ts) which injects the current workflow into every agent's
// system prompt; this tool gives agents a programmatic way to read/update it.
//
// State lives in <dataDir>/.opencode/workspace.json (seeded by the systemd
// setup script in modules/nixos/ai/comfyui/config.nix). Falls back to the
// most recently modified saved workflow when unset.

import { existsSync, readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

// When opencode runs from the ComfyUI data dir this is that dir (the .opencode
// project root). Same resolution as the plugin; tool files get cwd = project dir.
// Tolerate cwd == dataDir (normal) OR cwd == the .opencode dir itself.
const _cwd = process.cwd();
function findDataDir(cwd: string): string {
  if (existsSync(join(cwd, "user", "default", "workflows"))) return cwd;
  const parent = join(cwd, "..");
  if (existsSync(join(parent, "user", "default", "workflows"))) return parent;
  return cwd;
}
const dataDir = findDataDir(_cwd);
const stateFile = join(dataDir, ".opencode", "workspace.json");
const workflowsDir = join(dataDir, "user", "default", "workflows");

function readState(): { workflow: string; updated?: string; set_by?: string } | null {
  try {
    if (!existsSync(stateFile)) return null;
    const parsed = JSON.parse(readFileSync(stateFile, "utf8"));
    if (!parsed || typeof parsed.workflow !== "string" || !parsed.workflow) return null;
    return parsed;
  } catch {
    return null;
  }
}

function mostRecentWorkflow(): { workflow: string } | null {
  try {
    if (!existsSync(workflowsDir)) return null;
    const files = readdirSync(workflowsDir)
      .filter((f) => f.endsWith(".json"))
      .map((f) => {
        const p = join(workflowsDir, f);
        return { file: f, mtime: statSync(p).mtimeMs };
      })
      .sort((a, b) => b.mtime - a.mtime);
    return files[0] ? { workflow: `user/default/workflows/${files[0].file}` } : null;
  } catch {
    return null;
  }
}

interface Arg {
  action?: string;
  workflow?: string;
}

export default {
  description:
    "Get or set the active ComfyUI workflow (the 'workspace') for this opencode project. " +
    "Get (default) returns the current workflow, falling back to the most recently saved one. " +
    "Set points the whole project at a specific workflow for all agents. Use set when the user " +
    "explicitly names a workflow to work on.",
  args: {
    action: {
      type: "string",
      description: "'get' (default) reads the current workflow; 'set' writes a specific workflow.",
    },
    workflow: {
      type: "string",
      description:
        "Relative path to a saved workflow JSON, e.g. 'user/default/workflows/<name>.json'. Required when action=set.",
    },
  },
  async execute(args: Arg = {}) {
    const action = args.action ?? "get";

    if (action === "get") {
      const w = readState() ?? mostRecentWorkflow();
      if (!w) {
        return JSON.stringify({ error: "no workflow found; check user/default/workflows/", dir: dataDir }, null, 2);
      }
      return JSON.stringify(
        { workflow: w.workflow, updated: w.updated ?? null, set_by: w.set_by ?? null, dir: dataDir },
        null,
        2,
      );
    }

    if (action === "set") {
      const wf = args.workflow?.trim();
      if (!wf) return JSON.stringify({ error: "action=set requires a 'workflow' path" }, null, 2);
      const state = { workflow: wf, set_by: "agent", updated: new Date().toISOString() };
      try {
        writeFileSync(stateFile, JSON.stringify(state, null, 2) + "\n", "utf8");
        return JSON.stringify({ ok: true, ...state }, null, 2);
      } catch (e) {
        return JSON.stringify(
          { error: `failed to write ${stateFile}: ${e instanceof Error ? e.message : String(e)}` },
          null,
          2,
        );
      }
    }

    return JSON.stringify({ error: `unknown action '${action}' (use 'get' or 'set')` }, null, 2);
  },
};