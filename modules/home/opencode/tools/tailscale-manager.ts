import { execSync } from "node:child_process";

export default {
  description: "Get tailscale-manager status as JSON. Requires sudo.",
  args: {},
  async execute() {
    try {
      const out = execSync("sudo tailscale-manager status --json", {
        encoding: "utf-8",
        timeout: 15_000,
      });
      return JSON.stringify(JSON.parse(out), null, 2);
    } catch (e: any) {
      const stderr = e.stderr || "";
      return `tailscale-manager failed:\n${stderr}`;
    }
  },
};
