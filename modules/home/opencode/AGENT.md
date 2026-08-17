# modules/home/opencode/AGENT.md

> **Scope:** OpenCode AI coding agent configuration
> **Module:** `my.programs.opencode`

---

## Module Purpose

Configures [OpenCode](https://opencode.ai), an AI coding agent for the terminal,
with support for 15+ LLM providers and custom skills, tools, and agents.

---

## Directory Structure

```
modules/home/opencode/
├── default.nix      # Import manifest
├── meta.nix         # Machine-readable metadata
├── options.nix      # Option declarations (my.programs.opencode.*)
├── config.nix       # Main implementation
├── providers.nix    # LLM provider configuration logic
├── providers.md     # Provider documentation
├── tests.nix        # Module tests
├── README.md        # Human documentation
├── AGENT.md         # This file
├── agents/          # Custom agent prompt definitions (researcher.md)
├── commands/        # Custom slash-command definitions (nix-refine.md, ...)
├── skills/          # Custom skill definitions
├── plugins/         # Local opencode plugins
└── tools/           # Local MCP tool definitions
```

---

## Key Options

| Option | Purpose |
|--------|---------|
| `enable` | Enable opencode |
| `model` | Default model (provider/model-id) |
| `*.keyFile` | API key files for cloud providers |
| `ollamaModels` | Local Ollama models to register |
| `skills` | Custom skills for opencode |
| `tools` | Custom tools for opencode |
| `agents` | Custom agent configurations |
| `mcp` | MCP server configurations |

---

## Skills System

Skills provide context-aware instructions to opencode for specific tasks.
They are stored in `$XDG_CONFIG_HOME/opencode/skills/<name>/SKILL.md`.

### Available Skills

| Skill | Description |
|-------|-------------|
| `git-repo-management` | Git repository management patterns, gitreposync service |
| `deploy-workflow` | Deploying NixOS via nixos-anywhere, Ventoy USB, and related tools |
| `docker-management` | Docker/Podman containers, Ollama, and OCI tooling |
| `module-development` | Creating modules following repo conventions |
| `nixos-configuration` | Working with this NixOS configuration repository |
| `nixos-ensemble-decomposition` | Splitting NixOS work into parallel team slices |
| `opencode-ensemble` | Coordinating ensemble teams, delegating, reviewing teammate output |
| `secrets-management` | Managing agenix-encrypted secrets |
| `testing-patterns` | Writing and running tests |
| `windows-integration` | Windows dual-boot, DSC, unattended installs via Ventoy |

### Adding New Skills

Add skills via the `my.programs.opencode.skills` option:

```nix
my.programs.opencode.skills.my-skill = ''
  # SKILL.md content here
  # Describe patterns, conventions, and tasks
'';
```

Skills should follow the [OpenCode skills documentation](https://opencode.ai/docs/skills/).

---

## Provider Categories

### SDK-based (env-var keys)
- OpenAI, Anthropic, Google, Groq, Mistral, xAI, DeepInfra

### OpenAI-compatible (file substitution)
- Together, OpenRouter, Fireworks, Cerebras, Clarifai

### First-class (auth.json only)
- OpenCode Go, OpenCode Zen

### Local
- Ollama

---

## Integration Points

- **agenix**: API keys read from age-encrypted secrets
- **home-manager**: User environment and config files
- **MCP**: Model Context Protocol servers for extended capabilities

---

## Conventions

1. **Never commit API keys**: Always use `keyFile` options with agenix
2. **Prefer local models**: Ollama for privacy-sensitive work
3. **Use skills for repo patterns**: Document conventions in skills
4. **Agent permissions**: Restrict `plan`/`explore` agents, allow `build`
5. **Self-improving agents**: Agent prompts that want to learn from runs use the
   `SELF_IMPROVE` toggle + RUN LOG pattern (see `agents/researcher.md`, mirroring
   `commands/nix-refine.md`); scope `edit` permission to the agent's own file.

---

## Learning Promotion (self-improvement pipeline)

Proposed agent learnings (`learning_append`) are reviewed and promoted via
`learning_promote`, the ONLY path that flips `learnings.status`. Promotion is
**fully automated — no human gate**: both the **`build`** agent and the
dedicated **`learning-promoter`** agent
(`agents/learning-promoter.md`, `commands/learning-promote.md`) have runtime
permission to call `goals_learning_promote` (`config.nix`), and the promoter
runs from a persistent tmux TUI (NOT `opencode run`, which disposes the lead
instance mid-triage). A session promotes only on a **unanimous,
harness-re-derived triage `agree`** (no `disagree`/`uncertain` present; every
`review_verdicts` row has `rederivation_method IS NOT NULL`), applying each
accepted learning as an isolated commit and **auto-merging it into the base
branch** (`server`); git history is the audit/rollback net. This is enforced by
assertions in `tests.nix` (Decision 1: `build` + `learning-promoter` may allow
`goals_learning_promote`; every triage/reviewer role must deny it). The three
triage roles (`scout-skeptical`, `qa-verification`, `adversarial`) must deny it,
so a learning never self-certifies.

## Self-Improvement

Follow the self-improvement protocol in `../../../AGENTS.md` §11: at the end of
every session, fix anything in this file that misled you, went stale, or is
missing — grounded in what actually happened this session or exists in the repo
now, never aspirational. Record each applied change in the RUN LOG below.

## RUN LOG

### 2026-08-17 — two-agent promote model + auto-merge + tmux-TUI launch (revised above)
- Lesson: the "single promote-capable agent, detached/headless, no auto-merge"
  model above went stale after the owner asked for a fully no-human loop: build
  was granted `goals_learning_promote`, the promoter started auto-merging, and
  `opencode run` proved unable to host the promoter (disposes the lead instance
  at turn end, aborting async reviewers).
- Fix: `build` + `learning-promoter` are both promote-capable; the `tests.nix`
  Decision-1 assertions were revised to allow both and deny every triage role;
  accepted learnings auto-merge into `server`; the promoter now runs from a
  persistent tmux TUI (see `agents/learning-promoter.md` and
  `commands/learning-promote.md` for the launch steps). Rewrote the promotion
  section above to match.

### 2026-08-16 — added automated full-auto learning promotion (learning-promoter)
- Lesson: promotion of proposed agent learnings was documented as human-only,
  but the `learning_promote` server guard is config-level, not server-enforced —
  no identity check. There was also no tool that read `review_verdicts` back, so
  neither triage-review nor a promoter could see verdicts.
- Fix: added the `learning-promoter` agent (`agents/learning-promoter.md` + the
  `learning-promote` command) as the single promote-capable agent, kept the
  three-role re-derivation triage gate, applied each accepted learning to an
  isolated revertible branch, and extended `learning_query` to return each
  learning's `review_verdicts`. Added `tests.nix` assertions enforcing that
  exactly one agent may allow `goals_learning_promote`. Documented the pipeline
  in this file and updated the human-only claims in `AGENTS.md`, `modules/AGENT.md`,
  `researcher.md`, `build.md`, `nix-refine.md`, `nix-doc-audit.md`,
  `triage-review.md`, and `mcp_server.py`.

### 2026-08-07 — moved researcher agent into the module as a self-improving prompt
- Lesson: the `researcher` subagent lived only in the project-level
  `.opencode/opencode.json` (inline read-only prompt), inconsistent with every
  other agent being defined in `my.programs.opencode.agents`. It had no way to
  learn from runs, unlike the self-improving command files.
- Fix: added `agents/researcher.md` (research guidelines + `SELF_IMPROVE`
  toggle + RUN LOG, mirroring `nix-refine`), wired it as
  `my.programs.opencode.agents.researcher` with `edit` scoped to its own file,
  and removed the now-duplicate `.opencode/opencode.json`.

### 2026-08-05 — added self-improvement protocol
- Lesson: this file had no mechanism for sessions to record guidance fixes, so
  opencode/agent-convention drift could accumulate unnoticed.
- Fix: added this section pointing to the root `AGENTS.md` §11 protocol and a RUN
  LOG for dated entries.

---

## See Also

- `modules/nixos/gitreposync/` - Git repository sync service
- `modules/home/core/git.nix` - Git configuration
- [OpenCode Docs](https://opencode.ai/docs/)
