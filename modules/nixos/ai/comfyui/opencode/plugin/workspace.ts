// comfyui-workspace — project-local plugin for the ComfyUI instance's opencode.
//
// "WORKSPACE" here means the active ComfyUI workflow (a saved UI-format JSON
// under user/default/workflows/) that the user is currently working on. The
// point is that ANY newly spawned agent session started from this directory
// should immediately know which workflow to treat as the current workspace,
// without the user having to restate it every time.
//
// How it works:
//   * The systemd setup script (modules/nixos/ai/comfyui/config.nix) seeds a
//     writable state file at <dataDir>/.opencode/workspace.json — the single
//     source of truth. Its shape:
//         { "workflow": "user/default/workflows/<name>.json",
//           "set_by": "seed|human|agent", "updated": "<ISO8601>" }
//   * "experimental.chat.system.transform" appends a context block to the
//     system prompt of EVERY session started here (including subagents). The
//     block names the current workflow so agents know what to work on.
//   * "shell.env" additionally exports OPENCODE_COMFYUI_WORKSPACE so commands
//     and tools can read the active workflow as a plain env var.
//   * The companion tool file (tools/comfyui-workspace.ts) exposes get/set
//     for agents; this plugin deliberately avoids node_modules imports (only
//     Bun built-ins) so it keeps working when symlinked from the nix store.
//
// Auto-discovery: this file lives at .opencode/plugin/workspace.ts so opencode
// loads it with no config entry. It only ever runs for the ComfyUI project.

import type { Plugin } from "@opencode-ai/plugin";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

// <dataDir> is the parent of the .opencode dir the plugin lives in.
const stateFile = (directory: string) => join(directory, ".opencode", "workspace.json");
const workflowsDir = (directory: string) => join(directory, "user", "default", "workflows");

type WorkspaceState = { workflow: string; updated?: string; set_by?: string };

let lastKnown: { workflow: string; updated?: string } | null = null;

function readState(directory: string): WorkspaceState | null {
  const file = stateFile(directory);
  try {
    if (!existsSync(file)) return null;
    const parsed = JSON.parse(readFileSync(file, "utf8"));
    if (!parsed || typeof parsed.workflow !== "string" || !parsed.workflow) return null;
    return {
      workflow: parsed.workflow,
      ...(typeof parsed.updated === "string" ? { updated: parsed.updated } : {}),
      ...(typeof parsed.set_by === "string" ? { set_by: parsed.set_by } : {}),
    };
  } catch {
    return null;
  }
}

// Fall back to the most recently modified saved workflow so a fresh data dir
// (no state file / no explicit selection) still yields something useful.
function mostRecentWorkflow(directory: string): WorkspaceState | null {
  const dir = workflowsDir(directory);
  try {
    if (!existsSync(dir)) return null;
    const files = readdirSync(dir)
      .filter((f) => f.endsWith(".json"))
      .map((f) => {
        const p = join(dir, f);
        return { file: f, mtime: statSync(p).mtimeMs };
      })
      .sort((a, b) => b.mtime - a.mtime);
    return files[0] ? { workflow: `user/default/workflows/${files[0].file}` } : null;
  } catch {
    return null;
  }
}

function resolveWorkflow(directory: string): WorkspaceState | null {
  return readState(directory) ?? mostRecentWorkflow(directory);
}

function describe(workflow: string | null): string {
  if (!workflow) return "no workflow selected yet";
  const updated = lastKnown?.workflow === workflow && lastKnown.updated ? ` (updated ${lastKnown.updated})` : "";
  return `\`${workflow}\`${updated}`;
}

export default (async ({ directory }) => {
  const dir = directory && directory.length > 0 ? directory : process.cwd();
  const known = readState(dir);
  lastKnown = known ? { workflow: known.workflow, updated: known.updated } : null;

  return {
    // ── Inject the current workspace into every agent's system prompt ──────
    "experimental.chat.system.transform": async (_input, output) => {
      const resolved = resolveWorkflow(dir);
      const workflow = resolved?.workflow ?? null;
      lastKnown = workflow ? { workflow, updated: resolved?.updated } : null;

      const block = [
        "",
        "## Current ComfyUI workspace (injected by comfyui-workspace plugin)",
        "",
        `The ComfyUI workflow you should treat as the ACTIVE workspace is: ${describe(workflow)}.`,
        workflow
          ? "Unless the user says otherwise, work on THIS workflow: read/summarize it, " +
            "answer questions about it, and make edits/validations against it rather than " +
            "guessing or picking a different one."
          : "No workflow is currently selected. If asked which workflow to work on, list " +
            "`user/default/workflows/` and either ask the user which to pick or use the " +
            "most recent.",
        "You can switch the active workspace at any time by running the `comfyui-workspace` " +
          "tool (action=set) — do so when the user explicitly indicates a different workflow.",
      ].join("\n");

      if (!output.system) output.system = [];
      output.system.push(block);
    },

    // ── Export the active workflow as an env var for shells/tools ──────────
    "shell.env": async (_input, output) => {
      const workflow = resolveWorkflow(dir)?.workflow ?? "";
      output.env = { ...(output.env ?? {}), OPENCODE_COMFYUI_WORKSPACE: workflow };
    },
  };
}) satisfies Plugin;