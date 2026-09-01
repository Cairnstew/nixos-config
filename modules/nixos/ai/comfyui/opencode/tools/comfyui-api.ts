// comfyui-api — talk to the local ComfyUI instance (http://127.0.0.1:8188).
// Read-only queries: system stats, queue, history, object info, installed models.
// For running workflows / generating images prefer the comfyui MCP server
// (wired in this dir's .opencode/opencode.json).

interface Arg {
  action?: string;
  promptId?: string;
  nodeClass?: string;
}

const BASE = process.env.COMFYUI_URL || "http://127.0.0.1:8188";

async function api(action: string, promptId?: string, nodeClass?: string) {
  switch (action) {
    case "system-stats":
      return await get("/system_stats");
    case "queue":
      return await get("/queue");
    case "prompt":
      return await get("/prompt");
    case "history": {
      const suffix = promptId ? `?prompt_id=${encodeURIComponent(promptId)}` : "";
      return await get(`/history${suffix}`);
    }
    case "object-info": {
      const all = await get("/object_info");
      if (nodeClass) {
        const info = all?.[nodeClass];
        if (!info) return { error: `unknown node class: ${nodeClass}` };
        return {
          [nodeClass]: {
            input: info.input,
            output: info.output,
            description: info.description,
          },
        };
      }
      return Object.keys(all || {}).sort();
    }
    case "models":
      return await get("/models");
    default:
      return { error: `unknown action '${action}' (use system-stats|queue|prompt|history|object-info|models)` };
  }
}

async function get(path: string) {
  const res = await fetch(`${BASE}${path}`, { signal: AbortSignal.timeout(10_000) });
  if (!res.ok) return { error: `HTTP ${res.status} on ${path}: ${await res.text()}` };
  return await res.json();
}

export default {
  description:
    "Query the local ComfyUI instance (http://127.0.0.1:8188): system/GPU stats, queue, execution history, available node classes (object_info), and installed models. Read-only — use the comfyui MCP server for generating images or running workflows.",
  args: {
    action: {
      type: "string",
      description:
        "system-stats | queue | prompt | history | object-info | models. history accepts promptId; object-info accepts nodeClass to show one node's signature.",
    },
    promptId: {
      type: "string",
      description: "(history only) Fetch a single execution's history by prompt id.",
    },
    nodeClass: {
      type: "string",
      description: "(object-info only) Fetch one node class's input/output signature, e.g. KSampler.",
    },
  },
  async execute(args: Arg = {}) {
    try {
      const out = await api(args.action || "system-stats", args.promptId, args.nodeClass);
      return JSON.stringify(out, null, 2);
    } catch (err) {
      return `comfyui-api error: ${err instanceof Error ? err.message : String(err)}`;
    }
  },
};