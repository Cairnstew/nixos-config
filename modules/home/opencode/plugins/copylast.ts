import { spawnSync } from "node:child_process";

// Copy the last assistant response to the system clipboard.
//
// OpenCode 2 no longer runs V1 plugin hook objects (`command.execute.before`).
// The V2 equivalent is a command transform whose `execute` replaces the
// file-backed `/copylast` prompt. The command still appears under both names
// the old hook intercepted.

type AnyContext = any;

function copyToClipboard(text: string): boolean {
  const candidates: Array<[string, string[]]> = [
    ["wl-copy", []],
    ["xclip", ["-selection", "clipboard"]],
    ["pbcopy", []],
  ];
  for (const [bin, args] of candidates) {
    const probe = spawnSync("sh", ["-c", `command -v ${bin}`], { encoding: "utf-8" });
    if (probe.status !== 0) continue;
    const result = spawnSync(bin, args, { input: text });
    if (result.status === 0) return true;
  }
  return false;
}

function messageText(message: any): string {
  // V2: { type: "assistant", content: [{ type: "text", text }] }
  // V1: { info: { role: "assistant" }, parts: [{ type: "text", text }] }
  const content = message?.content ?? message?.parts ?? [];
  if (!Array.isArray(content)) return "";
  return content
    .filter((part: any) => part?.type === "text" && typeof part.text === "string")
    .map((part: any) => part.text)
    .join("\n");
}

async function lastAssistantText(ctx: AnyContext, sessionID: string): Promise<string> {
  try {
    const response = await ctx.session.context({ sessionID });
    const messages = Array.isArray(response) ? response : (response?.data ?? []);
    for (let i = messages.length - 1; i >= 0; i--) {
      const message = messages[i];
      const role = message?.type ?? message?.info?.role;
      if (role !== "assistant") continue;
      const text = messageText(message);
      if (text) return text;
    }
  } catch {
    // Fall through to the empty result below.
  }
  return "";
}

export default {
  id: "nixos.copylast",
  async setup(ctx: AnyContext) {
    const names = ["copylast", "copy-last"];
    await ctx.command.transform((editor: any) => {
      for (const name of names) {
        editor.add({
          name,
          description: "Copy the last assistant response to the clipboard",
          async execute({ sessionID }: { sessionID: string }) {
            const text = await lastAssistantText(ctx, sessionID);
            const copied = text ? copyToClipboard(text) : false;

            // Best-effort user-visible result. A synthetic message does not
            // start a model turn.
            try {
              await ctx.session.synthetic({
                sessionID,
                text: copied
                  ? "Copied last response"
                  : text
                    ? "Could not copy last response: no clipboard tool found"
                    : "No assistant response found",
              });
            } catch {
              // Non-fatal.
            }
          },
        });
      }
    });
  },
};
