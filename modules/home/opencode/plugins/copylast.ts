import type { Plugin } from "@opencode-ai/plugin";

export const CopyLastPlugin: Plugin = async ({ client, $ }) => {
  return {
    "command.execute.before": async (input, output) => {
      if (input.command !== "copylast") return;

      let text = "";

      try {
        const msgs = await client.session.messages({ path: { id: input.sessionID } });
        const msgsArr = Array.isArray(msgs) ? msgs : [];

        for (let i = msgsArr.length - 1; i >= 0; i--) {
          const msg = msgsArr[i];
          if (msg.info?.role === "assistant") {
            text = (msg.parts || [])
              .filter((p: any) => p.type === "text")
              .map((p: any) => p.text)
              .join("\n");
            break;
          }
        }
      } catch {}

      if (text) {
        const clipBin = (await $`which wl-copy xclip pbcopy 2>/dev/null | head -1`.quiet()).stdout.toString().trim();
        if (clipBin) {
          await $`printf '%s' ${text} | ${clipBin}`.quiet();
        }
      }

      await client.tui.showToast({
        body: { message: text ? "Copied last response" : "No assistant response found", variant: text ? "success" : "warning" },
      });

      throw new Error("");
    },
  };
};
