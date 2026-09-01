---
description: Check the health of the local ComfyUI instance — service status, GPU/VRAM, queue, recent outputs.
---

You are diagnosing the local ComfyUI instance on this host. Gather a status
report and explain what it means for image-generation work.

Follow the `comfyui-development` skill for instance details (URL, data dir,
GPU constraints).

Report, in order:
1. **Service** — `systemctl is-active comfy-ui.service`; if not active, show
   `systemctl status comfy-ui.service --no-pager -n 30` and `journalctl -u
   comfy-ui.service -n 40 --no-pager` and diagnose the failure.
2. **API reachability** — curl `http://127.0.0.1:8188/system_stats` (or use the
   `comfyui-api` tool). If unreachable, say so and stop.
3. **GPU/VRAM** — `nvidia-smi` (host GPU) plus `/system_stats`: total/used
   VRAM, current utilization, CUDA/Python versions.
4. **Queue** — `GET /queue`: number running + pending; list their prompt ids.
5. **Recent outputs** — `comfyui-api` history action (or `ls -lt output/`), last
   3-5 files with sizes and timestamps.

Finish with a one-line verdict: green (healthy), degraded (why), or down
(root cause + likely fix). Do not modify anything.