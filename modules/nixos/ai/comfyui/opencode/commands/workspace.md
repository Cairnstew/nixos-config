---
description: View or set the active ComfyUI workflow (the "workspace") for this opencode project — see which saved workflow agents should be working on, list available workflows, or switch to a different one.
---

ComfyUI "workspace" tracking lets every agent session started from this
directory know which saved workflow is the active one (the `.opencode/workspace.json`
state file). Use this command to view or change it.

## View the current workspace

To see which workflow is currently the active workspace:

```
comfyui-workspace
```

This prints the current workflow (or the most recently saved one if none was
explicitly set), when it was set, and how it was set (seed/human/agent).

## List available workflows

To see every saved workflow you could switch to (under `user/default/workflows/`):

```
ls -lt user/default/workflows/
```

## Set the current workspace

To switch the active workspace to a specific saved workflow:

```
comfyui-workspace set user/default/workflows/<name>.json
```

Provide the relative path (under the ComfyUI data dir). Agents will then treat
that workflow as the active one going forward. The path is stored in
`<dataDir>/.opencode/workspace.json`.

## Notes

- The state file lives at `<dataDir>/.opencode/workspace.json` and is created
  automatically (seeded to the most recent workflow). Editing that file
  directly also works (`set_by` can be `human`).
- New agents automatically receive the current workspace in their system prompt
  via the `comfyui-workspace` plugin — no need to restate it manually each time.
- The active workflow is also exported to shells as `OPENCODE_COMFYUI_WORKSPACE`.
