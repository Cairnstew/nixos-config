#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

async function git(args: string, cwd: string): Promise<string> {
  try {
    const { stdout, stderr } = await execAsync(`git ${args}`, { cwd });
    return stdout || stderr;
  } catch (e: any) {
    return e.stderr || e.message;
  }
}

const server = new Server(
  { name: "mcp-git", version: "1.0.0" },
  { capabilities: { tools: {} } },
);

const repoArg = {
  repo_path: { type: "string", description: "Path to Git repository" },
};

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "git_status",
      description: "Shows the working tree status",
      inputSchema: { type: "object", properties: repoArg, required: ["repo_path"] },
    },
    {
      name: "git_diff_unstaged",
      description: "Shows changes in the working directory that are not yet staged",
      inputSchema: { type: "object", properties: repoArg, required: ["repo_path"] },
    },
    {
      name: "git_diff_staged",
      description: "Shows changes that are staged for the next commit",
      inputSchema: { type: "object", properties: repoArg, required: ["repo_path"] },
    },
    {
      name: "git_diff",
      description: "Shows diff between two commits or refs",
      inputSchema: {
        type: "object",
        properties: {
          ...repoArg,
          target: { type: "string", description: "Target commit/ref (compared against HEAD)" },
        },
        required: ["repo_path", "target"],
      },
    },
    {
      name: "git_commit",
      description: "Records changes to the repository",
      inputSchema: {
        type: "object",
        properties: {
          ...repoArg,
          message: { type: "string", description: "Commit message" },
        },
        required: ["repo_path", "message"],
      },
    },
    {
      name: "git_add",
      description: "Stages file contents for the next commit",
      inputSchema: {
        type: "object",
        properties: {
          ...repoArg,
          files: { type: "array", items: { type: "string" }, description: "Files to stage" },
        },
        required: ["repo_path", "files"],
      },
    },
    {
      name: "git_reset",
      description: "Unstages all staged changes",
      inputSchema: { type: "object", properties: repoArg, required: ["repo_path"] },
    },
    {
      name: "git_log",
      description: "Shows the commit log",
      inputSchema: {
        type: "object",
        properties: {
          ...repoArg,
          max_count: { type: "number", description: "Maximum number of commits to show (default 10)" },
        },
        required: ["repo_path"],
      },
    },
    {
      name: "git_create_branch",
      description: "Creates a new branch",
      inputSchema: {
        type: "object",
        properties: {
          ...repoArg,
          branch_name: { type: "string", description: "Name of the new branch" },
          start_point: { type: "string", description: "Starting point for the new branch (optional)" },
        },
        required: ["repo_path", "branch_name"],
      },
    },
    {
      name: "git_checkout",
      description: "Switches branches",
      inputSchema: {
        type: "object",
        properties: {
          ...repoArg,
          branch_name: { type: "string", description: "Branch to checkout" },
        },
        required: ["repo_path", "branch_name"],
      },
    },
    {
      name: "git_show",
      description: "Shows the contents of a commit",
      inputSchema: {
        type: "object",
        properties: {
          ...repoArg,
          revision: { type: "string", description: "Commit hash or ref to show" },
        },
        required: ["repo_path", "revision"],
      },
    },
    {
      name: "git_branch",
      description: "Lists, creates, or deletes branches",
      inputSchema: {
        type: "object",
        properties: {
          ...repoArg,
          all: { type: "boolean", description: "Show all branches including remotes" },
        },
        required: ["repo_path"],
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  const a = args as Record<string, any>;
  const repo = a.repo_path as string;

  let output: string;

  switch (name) {
    case "git_status":
      output = await git("status", repo);
      break;
    case "git_diff_unstaged":
      output = await git("diff", repo);
      break;
    case "git_diff_staged":
      output = await git("diff --cached", repo);
      break;
    case "git_diff":
      output = await git(`diff HEAD ${a.target}`, repo);
      break;
    case "git_commit":
      output = await git(`commit -m ${JSON.stringify(a.message)}`, repo);
      break;
    case "git_add":
      output = await git(
        `add ${(a.files as string[]).map((f: string) => JSON.stringify(f)).join(" ")}`,
        repo,
      );
      break;
    case "git_reset":
      output = await git("reset HEAD", repo);
      break;
    case "git_log":
      output = await git(`log --oneline -${a.max_count ?? 10}`, repo);
      break;
    case "git_create_branch":
      output = await git(
        `checkout -b ${a.branch_name}${a.start_point ? ` ${a.start_point}` : ""}`,
        repo,
      );
      break;
    case "git_checkout":
      output = await git(`checkout ${a.branch_name}`, repo);
      break;
    case "git_show":
      output = await git(`show ${a.revision}`, repo);
      break;
    case "git_branch":
      output = await git(`branch${a.all ? " -a" : ""}`, repo);
      break;
    default:
      output = `Unknown tool: ${name}`;
  }

  return {
    content: [{ type: "text", text: output }],
  };
});

const transport = new StdioServerTransport();
await server.connect(transport);
