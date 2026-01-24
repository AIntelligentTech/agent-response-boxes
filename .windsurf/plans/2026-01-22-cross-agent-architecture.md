# Cross-Agent Response Boxes Architecture (Cursor, Windsurf, OpenCode)

This plan defines a cross-agent architecture and installer layout for Response Boxes that preserves a shared local event store while adapting capture, injection, and skills to Cursor, Windsurf, and OpenCode.

## Goals

- Preserve the existing **event-sourced** model (`boxes.jsonl`) and human-in-the-loop analysis.
- Make the system feel **native** per agent (rules/skills/hooks/plugins).
- Maximize automation where the agent supports it, while keeping **manual approvals** for writes beyond `BoxCreated`.
- Keep installs reversible: install/uninstall, scope aware (user vs project), dry-run, and minimal drift.

## Non-goals (for this phase)

- Implement other agents (Gemini/Codex/etc.).
- Cloud sync of the event store.
- Real-time learning generation without explicit user approval.

## Baseline: What exists today (Claude Code implementation)

- **Event store**: `~/.response-boxes/analytics/boxes.jsonl` (append-only JSONL).
- **Collector**: `hooks/session-processor.sh` (SessionEnd → emits `BoxCreated`).
- **Injector**: `hooks/inject-context.sh` (SessionStart → projects learnings/boxes → injects `additionalContext` + reminder).
- **Manual analysis**: `skills/analyze-boxes/SKILL.md` (user runs `/analyze-boxes`, approves writes).

Note: per current Claude Code docs, legacy custom slash commands in `.claude/commands/*.md` are effectively merged into skills; a command file and a `skills/<name>/SKILL.md` can both create the same `/name`. Prefer skills for new work.

## Capability matrix (what we can rely on)

### Cursor

- **Rules**: `.cursor/rules/*.md|.mdc` and `AGENTS.md` (simple alternative).
- **Skills**: `.cursor/skills/` and Claude-compatible `.claude/skills/`.
- **Hooks**:
  - `sessionStart` can return `additional_context` (true prompt injection).
  - `afterAgentResponse` provides assistant `text` (good for box capture).

### Windsurf (Cascade)

- **Rules**: `.windsurf/rules/` (workspace-scoped, auto-discovered) and also supports directory-scoped `AGENTS.md`.
  - Rules support activation modes (manual, always_on, model_decision, glob) and are limited to ~12k chars each.
  - Rules commonly use YAML frontmatter for `trigger` and optional `globs`.
- **Skills**: `.windsurf/skills/` (workspace) and `~/.codeium/windsurf/skills/` (global).
- **Hooks**:
  - `post_cascade_response` provides full response markdown (good for capture).
  - Hooks are shell commands with stdin JSON and exit codes; docs describe blocking pre-hooks but do not describe a supported "return additional prompt context" mechanism.
- **Workflows**: `.windsurf/workflows/` invoked via `/workflow-name` (slash-command automation).
  - Workflows are the supported way to run multi-step “start of session” behavior (e.g., project learnings and present them).

### OpenCode

- **Rules**: `AGENTS.md` (project) and `~/.config/opencode/AGENTS.md` (global).
  - Claude compatibility fallbacks: `CLAUDE.md`, `~/.claude/skills/`.
  - `opencode.json` supports `instructions: [...]` (globs + URLs).
- **Skills**: `.opencode/skills/` and Claude-compatible `.claude/skills/`.
- **Plugins**:
  - Rich event surface (`message.updated`, `tool.execute.*`, etc.).
  - Plugin hooks include `experimental.chat.system.transform` which can inject additional strings into the system prompt per session.
  - SDK still supports `client.session.prompt({ noReply: true, ... })`, but `experimental.chat.system.transform` is the more direct “prompt injection” mechanism.

### OpenCode output-style replication (decision)

- **Why**: Response Boxes rely on a strong, always-on output style (pre-response
  checklist, box formats, and usage rules). OpenCode does not have a literal
  “output style” feature, so we must choose how to replicate this behavior.
- **Options considered**:
  - **A — Static instructions via `AGENTS.md` / `opencode.json`**
    - Put the Response Boxes spec (or a distilled version) into OpenCode’s
      instruction system using `instructions: [...]` globs/paths.
    - Pros: Simple, transparent, version-controlled; mirrors Claude Code’s
      `CLAUDE.md` + rules approach.
    - Cons: Users must manage instruction size and ordering.
  - **B — Plugin-based injection of output style**
    - Use `experimental.chat.system.transform` to push the full output style
      text into the system prompt on every session.
    - Pros: Centralized; no manual config edits.
    - Cons: Couples static spec to plugin, harder to see/edit, and risks
      overloading the system prompt budget.
  - **C — No explicit replication**
    - Rely only on dynamic learnings/boxes injection.
    - Cons: Loses the core response-box ergonomics and consistency.
- **Decision**:
  - Use **Option A** as the primary path:
    - Provide Response Boxes instructions/spec as files that OpenCode loads via
      `AGENTS.md` or `opencode.json` `instructions` entries.
    - Treat this as the OpenCode analogue of the Claude Code output style.
  - Use the **OpenCode plugin only for dynamic context** (prior learnings and
    notable boxes) via `experimental.chat.system.transform`, not for static
    box spec.

## Approaches (comparison with reasoned arguments)

### Approach A — “Skills-only” (Agent Skills standard everywhere)

**Idea**: distribute only SKILL.md + rules; user manually runs workflows/commands for capture/inject.

- Pros:
  - Lowest engineering effort and maintenance.
  - Portable across Cursor/Windsurf/OpenCode because all support (or emulate) Agent Skills.
  - Avoids brittle hook/plugin APIs.
- Cons:
  - Loses the biggest UX value: automatic capture + automatic reminders/context.
  - Requires humans to remember to run capture/inject steps.
- Best fit:
  - Windsurf injection (until proven otherwise), and as a baseline fallback for all agents.

### Approach B — Agent-native automation per agent (hooks/plugins)

**Idea**: implement capture/inject using each agent’s native extension points.

- Pros:
  - Best user experience; matches each agent’s “way of working”.
  - Allows true auto-injection where supported (Cursor, OpenCode).
- Cons:
  - More code paths and testing complexity.
  - Different security models and payload schemas.
- Best fit:
  - Cursor (strongest hook support).
  - OpenCode (plugin + SDK is powerful).
  - Windsurf capture only (hook supports capture; injection likely needs workflow).

### Approach C — Universal “response-boxes CLI” (agent-agnostic core)

**Idea**: extract the durable logic into a small local CLI, then have hooks/plugins call it.

- Pros:
  - Centralizes parsing/projection logic (less duplication than writing per-agent scripts).
  - Hooks/plugins become thin adapters.
  - Easier to add new agents later.
- Cons:
  - Adds a runtime dependency and install surface (bun/node/python).
  - Must design for safe execution + stable interface.
- Best fit:
  - Multi-agent parity once Cursor/OpenCode/Windsurf adapters exist.

### Approach D — OpenSkills (external installer/loader for SKILL.md)

**What it is**: OpenSkills is a third-party CLI that installs SKILL.md and generates `<available_skills>` XML into `AGENTS.md`, allowing any “AGENTS.md-capable” agent to load skills via `npx openskills read <name>`.

- Pros:
  - Helps agents that **don’t** natively support the Agent Skills discovery mechanism.
  - Enables “universal mode” (.agent/skills) in mixed-agent setups.
- Cons:
  - External dependency and extra step (`npx openskills sync`).
  - Cursor/Windsurf/OpenCode already support skills natively; benefit is mostly indirect.
  - Adds a second, parallel skills story that can confuse users.
- Recommended stance:
  - Treat as an **optional** integration path (especially for agents without native skills); not the primary path for Cursor/Windsurf/OpenCode.

## Recommended architecture (hybrid)

### Core invariants

- Keep a single authoritative event store (`~/.response-boxes/analytics/boxes.jsonl`).
- Keep analysis human-in-the-loop (no auto appends beyond `BoxCreated`).
- Maintain schema guardrails/legacy normalization.

### Adapter model

- **Collector adapter** per agent:
  - Input: assistant response text (Cursor hook / Windsurf post_cascade_response / OpenCode message events).
  - Output: `BoxCreated` events appended to the shared event store.
- **Injector adapter** per agent:
  - Cursor: `sessionStart` hook returns `additional_context`.
  - OpenCode: plugin injects projected context via `experimental.chat.system.transform` when the system prompt is built (typically once per session).
  - Windsurf: use a workflow `/response-boxes-start` to print projected context and instruct Cascade to include it (manual but ergonomic).
- **Skill distribution**:
  - Continue shipping `skills/analyze-boxes/SKILL.md` as canonical.
  - Install it into each agent’s native skills directory (and optionally `.claude/skills` for compatibility).

### Modes: basic vs full

- **Basic mode** (prompt-only):
  - Installs only **prompt-level assets**:
    - Output style / instructions (where supported).
    - Rules/spec files (Response Boxes taxonomy and usage rules).
    - CLAUDE/AGENTS snippets that teach the box workflow.
  - **No event store** (`boxes.jsonl`), no hooks/plugins, no `/analyze-boxes` skill.
  - Goal: robust within-session metacognition without cross-session persistence.

- **Full mode** (event-sourced learning loop):
  - Everything from basic mode, plus:
    - Shared event store at `~/.response-boxes/analytics/boxes.jsonl`.
    - Per-agent collector and injector adapters.
    - `/analyze-boxes` skill wired into the agent’s skills system.
  - Goal: end-to-end loop (capture → analyze → inject) with durable learnings.

## Proposed repo/installer layout

### Repo additions (high level)

- `agents/claude-code/` (canonical Claude Code adapter)
  - `hooks/inject-context.sh` + `hooks/session-processor.sh`
  - `rules/response-boxes.md` (full spec consumed by all agents)
  - `output-styles/response-box.md` (Response Box output style)
  - `skills/analyze-boxes/SKILL.md` (canonical analysis skill)
  - `config/claude-md-snippet.md` (snippet for CLAUDE.md and other instruction files)
- `agents/cursor/` templates
  - `.cursor/hooks.json` + hook scripts
  - `.cursor/skills/analyze-boxes/SKILL.md` (or symlink/copy)
  - `.cursor/rules/` rule(s) that teach Response Box formatting
- `agents/windsurf/` templates
  - `.windsurf/hooks.json` for `post_cascade_response` capture
  - `.windsurf/workflows/response-boxes-start.md` for “manual injection”
  - `.windsurf/skills/analyze-boxes/SKILL.md`
- `agents/opencode/` templates
  - `plugins/response-boxes.plugin.ts` (OpenCode plugin: capture + inject)
  - `.opencode/skills/analyze-boxes/SKILL.md` (optional mirror of canonical skill)
  - `AGENTS.md` / `opencode.json` snippet using `instructions` to pull in Response Box rules/spec

### Installer strategy

- Prefer **one entrypoint** with subcommands:
  - `install.sh --agent cursor|windsurf|opencode [--user|--project] [--dry-run] [--force] [--uninstall]`
- Keep agent-specific file placement as data-driven as possible (copy templates, minimal logic).

## Key design details / pitfalls to handle

- **Idempotency**:
  - Hooks/plugins must not double-append the same `BoxCreated` for the same response.
  - Use deterministic IDs where possible (e.g., hash of response + timestamp window, or per-session counters where available).
- **Loop safety (OpenCode plugin)**:
  - Injecting context via `noReply: true` must not retrigger capture/inject loops.
  - Keep a per-session marker (in-memory + persisted small state file) that injection already happened.
- **Security/privacy**:
  - Windsurf `post_cascade_response` includes full trajectory-like content; treat it as sensitive.
  - Provide an opt-out env var per agent (e.g., `RESPONSE_BOXES_DISABLED=true`).
- **Windsurf injection uncertainty**:
  - Docs do not state hooks can inject prompt context. Assume “no” until tested.

## Verification plan (for implementation phase)

- Cursor:
  - Start a session → confirm `additional_context` contains projected learnings/reminder.
  - Produce a response with a box → confirm a new `BoxCreated` is appended.
- Windsurf:
  - Produce a response with a box → confirm capture hook appends `BoxCreated`.
  - Run `/response-boxes-start` workflow → confirm it prints projected context and is usable.
- OpenCode:
  - Start session → plugin injects context via `noReply: true` once.
  - Agent response updates → plugin captures boxes and appends events.

## Open questions (need user decision or an experiment)

- Windsurf injection approach (decided): use **both**
  - **Always-on rules**: persistent guidance and reminders (static context)
  - **Workflow** (e.g. `/response-boxes-start`): dynamic projection + presentation of learnings/boxes (runtime context)
