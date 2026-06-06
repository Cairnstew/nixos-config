import { execSync } from "node:child_process";

export default {
  description: "Show agenix-manager secret status table. Requires sudo.",
  args: {},
  async execute() {
    try {
      const out = execSync("sudo agenix-manager status", {
        encoding: "utf-8",
        timeout: 15_000,
      });
      return out;
    } catch (e: any) {
      const stderr = e.stderr || "";
      return `agenix-manager failed:\n${stderr}`;
    }
  },
};
