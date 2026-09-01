---
description: Inspect, author, convert or validate a ComfyUI workflow — reading the saved library, converting UI↔API format, and validating before a run.
---

You are working with ComfyUI workflows on this host. The user wants to inspect,
create, convert, or validate a workflow.

Follow the `comfyui-development` skill for instance details (URL, data dir,
workflow locations, API format).

Common flows:
- **List/read saved workflows**: `ls -la user/default/workflows/` under the
  ComfyUI data dir; read one with `cat`. These are UI-format JSON
  (`nodes`/`links`, version 0.4). Summarize the graph (nodes, connections,
  model files referenced, resolution, sampler settings).
- **Convert UI → API format** so it can run: produce the API-format graph
  (`{"id": {"class_type": ..., "inputs": {...}}}`) by walking nodes/links;
  use `GET /object_info` to confirm exact class names and input signatures.
  Point out anything missing (unconnected inputs, missing model files).
- **Validate a workflow before running**: enqueue nothing; dry-run check for
  missing node classes (`GET /object_info` keys), broken links, missing model
  files under `models/`, and inputs without values.
- **Save a new workflow**: write to `user/default/workflows/<name>.json` (UI
  format) when the user asks to persist it.

Never enqueue/run a workflow unless the user explicitly asks to generate an
image. If you find a broken workflow, explain the failure and propose a fix,
then apply it only with the user's OK.