import { tool } from "@opencode-ai/plugin";
import { execSync } from "node:child_process";
import { writeFileSync, unlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

export default tool({
  description:
    "Write text to the system clipboard. Use this when the user asks you to copy content to their clipboard.",

  args: {
    text: tool.schema
      .string()
      .describe("The text content to copy to the clipboard"),
  },

  async execute(args) {
    const { text } = args;

    const tmp = join(tmpdir(), `opencode-clip-${Date.now()}.txt`);
    writeFileSync(tmp, text, "utf-8");

    try {
      execSync("wl-copy", { input: text, timeout: 5_000 });
      unlinkSync(tmp);
      const preview = text.length > 200 ? text.slice(0, 200) + "..." : text;
      return `Copied to clipboard:\n\n${preview}`;
    } catch {
      // wl-copy not available, try next
    }

    try {
      execSync(`xclip -selection clipboard -in ${tmp}`, {
        timeout: 5_000,
      });
      unlinkSync(tmp);
      const preview = text.length > 200 ? text.slice(0, 200) + "..." : text;
      return `Copied to clipboard:\n\n${preview}`;
    } catch {
      // xclip not available, try next
    }

    try {
      execSync("pbcopy", { input: text, timeout: 5_000 });
      unlinkSync(tmp);
      const preview = text.length > 200 ? text.slice(0, 200) + "..." : text;
      return `Copied to clipboard:\n\n${preview}`;
    } catch {
      // pbcopy not available
    }

    unlinkSync(tmp);
    return "Failed: no clipboard tool found (tried wl-copy, xclip, pbcopy).";
  },
});
