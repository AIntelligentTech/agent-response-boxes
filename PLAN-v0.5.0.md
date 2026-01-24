# Response Boxes v0.5.0 Implementation Plan

**Status:** Draft **Created:** 2026-01-24 **Target Completion:** 2026-02-14 (3
weeks) **Authors:** AI-assisted planning

---

## Executive Summary

This plan targets the v0.5.0 release of Response Boxes, focusing on:

1. **Repository cleanup** - Consolidate duplicate file structure
2. **Cross-agent parity** - Implement full-mode support for Cursor and Windsurf
3. **Production readiness** - Add tests, CI/CD, and GitHub infrastructure
4. **Documentation** - Comprehensive cross-agent compatibility docs

---

## Goals

1. Achieve **80%+ feature parity** across Claude Code, OpenCode, Cursor, and
   Windsurf
2. Establish **automated testing** with >70% code coverage for critical paths
3. Create **GitHub Actions CI/CD** pipeline for all PRs
4. Consolidate **repository structure** to single source of truth
5. Document **cross-agent compatibility** with verified capability matrices

## Non-Goals

- Cloud sync for event store (deferred to v1.0)
- Web dashboard (deferred to v1.0)
- Response Boxes CLI tool (evaluate for v0.6.0)
- Additional agents (Gemini CLI, Aider, Continue) beyond basic AGENTS.md support

---

## Current State Assessment

### What Exists (v4.0.0)

| Component               | Claude Code | OpenCode        | Windsurf | Cursor   |
| ----------------------- | ----------- | --------------- | -------- | -------- |
| Box taxonomy (13 types) | ✅ Full     | ✅ Full         | ✅ Full  | ✅ Full  |
| Output style            | ✅ Native   | ⚠️ Instructions | ⚠️ Rules | ⚠️ Rules |
| SessionStart injection  | ✅ Hook     | ✅ Plugin       | ❌ None  | ❌ None  |
| SessionEnd collection   | ✅ Hook     | ✅ Plugin       | ❌ None  | ❌ None  |
| Event store integration | ✅ Full     | ✅ Full         | ❌ None  | ❌ None  |
| /analyze-boxes skill    | ✅ Full     | ⚠️ Reuse        | ❌ None  | ❌ None  |

### Capability Research Findings (January 2026)

#### Cursor (v1.7+)

**Hooks Available:**

- `afterAgentResponse` - Captures assistant text (observation-only)
- `afterAgentThought` - Captures thinking blocks
- `beforeSubmitPrompt` - Observes user queries
- `preToolUse` / `postToolUse` - Tool lifecycle hooks

**Critical Limitation:** Hooks are **observation-only**. No mechanism to:

- Inject context into next prompt
- Modify agent state
- Trigger session-start actions

**Full-Mode Feasibility:** ❌ NOT POSSIBLE with current Cursor architecture

- Collection: ✅ Possible via `afterAgentResponse`
- Injection: ❌ No API for session-start context injection

**Recommended Approach:** Enhanced basic mode with manual workflow

#### Windsurf (Cascade v1.12.41+)

**Hooks Available:**

- `post_cascade_response` - Full model output with trajectory
- `pre_user_prompt` / `post_user_prompt` - Prompt lifecycle
- `pre_read_code` / `post_read_code` - File operations
- `pre_write_code` / `post_write_code` - Code modifications
- `pre_run_command` / `post_run_command` - Terminal execution

**Critical Limitation:** Hooks cannot return `additional_context`

- Pre-hooks: Exit codes only (0=allow, 2=block)
- Post-hooks: Observation only, no injection

**Memories System:** NOT programmatically accessible

**Full-Mode Feasibility:** ⚠️ PARTIAL

- Collection: ✅ Possible via `post_cascade_response`
- Injection: ⚠️ Requires workflow + rules workaround

**Recommended Approach:**

1. Collection hook for automatic capture
2. Workflow (`/response-boxes-start`) for manual injection
3. Rules for static guidance

#### OpenCode (v1.1.34+)

**Hooks Available:**

- `message.updated` - Real-time message tracking
- `experimental.chat.system.transform` - System prompt injection (now with
  sessionID)
- `chat.headers` - HTTP header modification (stable, new Jan 2026)
- `tool.execute.before` / `tool.execute.after` - Tool lifecycle
- `experimental.session.compacting` - Session state preservation

**Full-Mode Feasibility:** ✅ FULLY SUPPORTED

- Collection: ✅ Via `message.updated` event
- Injection: ✅ Via `experimental.chat.system.transform`

**Current Implementation Status:** 80% complete, needs:

- Native skill distribution (currently relies on Claude's `/analyze-boxes`)
- Static output style via AGENTS.md/instructions

---

## Implementation Phases

### Phase 1: Repository Cleanup (Days 1-3)

**P0 - Critical**

#### 1.1 Consolidate File Structure

Remove duplicate root-level directories:

```
DELETE: hooks/, rules/, output-styles/, skills/, config/
KEEP:   agents/claude-code/hooks/, agents/claude-code/rules/, etc.
```

Update all references in:

- `install.sh`
- `README.md`
- `docs/architecture.md`

#### 1.2 Fix GitHub Infrastructure

Create `.github/` directory:

```
.github/
├── ISSUE_TEMPLATE/
│   ├── bug_report.md
│   ├── feature_request.md
│   └── agent_support.md
├── PULL_REQUEST_TEMPLATE.md
├── CODEOWNERS
├── workflows/
│   ├── ci.yml
│   └── release.yml
└── FUNDING.yml (optional)
```

#### 1.3 Fix CODE_OF_CONDUCT.md

Replace `[INSERT CONTACT METHOD]` with actual contact:

```markdown
Instances of abusive behavior may be reported to:

- Email: conduct@aintelligenttech.com
- GitHub Issues (for public concerns)
```

#### 1.4 Create CHANGELOG.md

Document version history:

```markdown
# Changelog

## [4.0.0] - 2026-01-22

### Added

- Event-sourced architecture with boxes.jsonl
- AI-powered /analyze-boxes skill
- Cross-session learning with recency decay ...
```

---

### Phase 2: Testing Infrastructure (Days 4-7)

**P0 - Critical**

#### 2.1 Add Bash Testing Framework (bats)

```bash
tests/
├── hooks/
│   ├── inject-context.bats
│   └── session-processor.bats
├── installer/
│   └── install.bats
├── fixtures/
│   ├── sample-transcript.jsonl
│   ├── sample-boxes.jsonl
│   └── sample-response.md
└── test_helper.bash
```

Key test cases:

- Box parsing from various response formats
- Event emission to JSONL
- Legacy format migration
- Projection with recency decay
- Installer idempotency

#### 2.2 Add TypeScript Testing (vitest)

For OpenCode plugin:

```typescript
tests/
├── opencode/
│   ├── plugin.test.ts
│   ├── box-extraction.test.ts
│   └── context-injection.test.ts
└── fixtures/
    └── sample-messages.json
```

#### 2.3 Create CI/CD Pipeline

`.github/workflows/ci.yml`:

```yaml
name: CI
on: [push, pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: ShellCheck
        uses: ludeeus/action-shellcheck@master
        with:
          scandir: "./agents"
      - name: ESLint (OpenCode plugin)
        run: cd agents/opencode && bun install && bun lint

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install bats
        run: sudo apt-get install -y bats
      - name: Run bash tests
        run: bats tests/hooks/*.bats
      - name: Run TypeScript tests
        run: cd agents/opencode && bun test

  installer:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
    steps:
      - uses: actions/checkout@v4
      - name: Test installer (dry-run)
        run: ./install.sh --agent claude-code --dry-run
```

---

### Phase 3: Windsurf Full-Mode Implementation (Days 8-12)

**P1 - Important**

#### 3.1 Implement Collection Hook

Create `agents/windsurf/hooks/hooks.json`:

```json
{
  "hooks": {
    "post_cascade_response": {
      "command": "~/.response-boxes/hooks/windsurf-collector.sh"
    }
  }
}
```

Create `agents/windsurf/hooks/windsurf-collector.sh`:

```bash
#!/usr/bin/env bash
# Captures boxes from post_cascade_response and emits BoxCreated events
# Input: JSON via stdin with trajectory_id, execution_id, and full response

set -euo pipefail

BOXES_FILE="${RESPONSE_BOXES_FILE:-${HOME}/.response-boxes/analytics/boxes.jsonl}"

# Parse input
input="$(cat)"
response_text="$(echo "$input" | jq -r '.tool_info.response // ""')"
trajectory_id="$(echo "$input" | jq -r '.trajectory_id // ""')"

# Extract and emit boxes (reuse parsing logic)
# ... (similar to session-processor.sh)
```

#### 3.2 Create Injection Workflow

Create `agents/windsurf/workflows/response-boxes-start.md`:

```markdown
---
name: response-boxes-start
description: Initialize Response Boxes context for this session
---

# /response-boxes-start

This workflow projects learnings and notable boxes from prior sessions.

## Steps

1. Read the event store at `~/.response-boxes/analytics/boxes.jsonl`
2. Project top 3 learnings by confidence and recency
3. Project top 5 notable boxes relevant to this workspace
4. Present the context block for Cascade to incorporate

## Context Block

[Dynamically generated from event store]
```

#### 3.3 Update Windsurf Rules

Enhance `agents/windsurf/rules/response-boxes.md` to reference:

- The workflow for session start
- The hook for automatic collection
- Full box taxonomy with examples

#### 3.4 Update Installer

Add to `install.sh`:

```bash
install_windsurf_full() {
  # Install hooks.json
  # Install collector script
  # Install workflow
  # Install enhanced rules
}
```

---

### Phase 4: Cursor Enhanced Basic Mode (Days 13-16)

**P1 - Important**

Given Cursor's architectural limitations, implement "enhanced basic mode":

#### 4.1 Implement Collection Hook

Create `agents/cursor/hooks/hooks.json`:

```json
{
  "hooks": {
    "afterAgentResponse": {
      "command": "~/.response-boxes/hooks/cursor-collector.sh"
    }
  }
}
```

Create `agents/cursor/hooks/cursor-collector.sh`:

```bash
#!/usr/bin/env bash
# Captures boxes from afterAgentResponse
# Note: This is observation-only; no injection possible

set -euo pipefail

BOXES_FILE="${RESPONSE_BOXES_FILE:-${HOME}/.response-boxes/analytics/boxes.jsonl}"

input="$(cat)"
response_text="$(echo "$input" | jq -r '.text // ""')"

# Extract boxes and emit events
# ... (similar parsing logic)
```

#### 4.2 Create Manual Injection Skill

Create `agents/cursor/skills/response-boxes-context/SKILL.md`:

```markdown
---
name: response-boxes-context
description: Display prior session learnings and notable boxes
---

# /response-boxes-context

Manually invoke this skill at session start to see cross-session context.

## Instructions

1. Read `~/.response-boxes/analytics/boxes.jsonl`
2. Project learnings and boxes
3. Display formatted context block
4. User can reference this in their prompts
```

#### 4.3 Update Cursor Rules

Enhance `agents/cursor/rules/response-boxes.mdc`:

- Add instructions for manual context workflow
- Reference the collection hook
- Full box taxonomy

---

### Phase 5: OpenCode Completion (Days 17-19)

**P1 - Important**

#### 5.1 Add Native Skill Distribution

Create `agents/opencode/skills/analyze-boxes/SKILL.md`:

- Copy from `agents/claude-code/skills/analyze-boxes/SKILL.md`
- Adjust paths for OpenCode conventions

#### 5.2 Add Static Output Style

Create `agents/opencode/instructions/response-boxes.md`:

- Condensed version of output style
- Box taxonomy reference
- Pre-response checklist

Update install script to add to `opencode.json`:

```json
{
  "instructions": [
    "~/.response-boxes/agents/opencode/instructions/response-boxes.md"
  ]
}
```

#### 5.3 Plugin Improvements

Update `agents/opencode/plugins/response-boxes.plugin.ts`:

- Use `chat.headers` for session correlation (more stable)
- Add sessionID to BoxCreated events
- Improve ID generation (avoid Date.now() collisions)

---

### Phase 6: Documentation (Days 20-21)

**P1 - Important**

#### 6.1 Create Cross-Agent Compatibility Guide

Create `docs/cross-agent-compatibility.md` (detailed below)

#### 6.2 Update README.md

- Add compatibility matrix
- Add troubleshooting section
- Fix outdated paths
- Add badge for CI status

#### 6.3 Update architecture.md

- Add sequence diagrams for multi-agent scenarios
- Document plugin stability levels
- Add version requirements

#### 6.4 Create SECURITY.md

```markdown
# Security Policy

## Reporting a Vulnerability

Please report security vulnerabilities to security@aintelligenttech.com.

## Sensitive Data Handling

Response Boxes stores session data locally at `~/.response-boxes/analytics/`.
This data may contain:

- Code snippets from responses
- Project paths and git remotes
- Session metadata

We recommend:

- Adding `~/.response-boxes/` to backup exclusions if using cloud backup
- Reviewing boxes.jsonl periodically
- Using BOX_INJECT_DISABLED=true for sensitive projects
```

---

## Detailed Task Breakdown

### P0 Tasks (Must Complete)

| ID    | Task                                    | Est. Hours | Dependencies |
| ----- | --------------------------------------- | ---------- | ------------ |
| P0-1  | Delete root-level duplicate directories | 1          | None         |
| P0-2  | Update install.sh paths to agents/      | 2          | P0-1         |
| P0-3  | Update README paths                     | 1          | P0-1         |
| P0-4  | Create .github/ISSUE_TEMPLATE/\*        | 1          | None         |
| P0-5  | Create .github/PULL_REQUEST_TEMPLATE.md | 0.5        | None         |
| P0-6  | Create .github/CODEOWNERS               | 0.5        | None         |
| P0-7  | Fix CODE_OF_CONDUCT contact             | 0.25       | None         |
| P0-8  | Create CHANGELOG.md                     | 1          | None         |
| P0-9  | Create .github/workflows/ci.yml         | 2          | None         |
| P0-10 | Add bats test framework                 | 2          | None         |
| P0-11 | Write inject-context.bats               | 3          | P0-10        |
| P0-12 | Write session-processor.bats            | 3          | P0-10        |
| P0-13 | Write install.bats                      | 2          | P0-10        |
| P0-14 | Add vitest for OpenCode plugin          | 1          | None         |
| P0-15 | Write plugin tests                      | 3          | P0-14        |

**Total P0: ~23 hours**

### P1 Tasks (Should Complete)

| ID    | Task                                | Est. Hours | Dependencies |
| ----- | ----------------------------------- | ---------- | ------------ |
| P1-1  | Windsurf collector hook             | 3          | None         |
| P1-2  | Windsurf injection workflow         | 2          | None         |
| P1-3  | Windsurf enhanced rules             | 1          | None         |
| P1-4  | Windsurf installer integration      | 2          | P1-1, P1-2   |
| P1-5  | Cursor collector hook               | 2          | None         |
| P1-6  | Cursor manual context skill         | 2          | None         |
| P1-7  | Cursor enhanced rules               | 1          | None         |
| P1-8  | Cursor installer integration        | 1          | P1-5, P1-6   |
| P1-9  | OpenCode native skill               | 1          | None         |
| P1-10 | OpenCode static instructions        | 1          | None         |
| P1-11 | OpenCode plugin improvements        | 2          | None         |
| P1-12 | Create cross-agent-compatibility.md | 4          | Research     |
| P1-13 | Update README.md                    | 2          | P0-1         |
| P1-14 | Update architecture.md              | 2          | P1-12        |
| P1-15 | Create SECURITY.md                  | 1          | None         |

**Total P1: ~27 hours**

### P2 Tasks (Nice to Have)

| ID   | Task                        | Est. Hours | Dependencies |
| ---- | --------------------------- | ---------- | ------------ |
| P2-1 | Add test coverage badge     | 1          | P0-11, P0-15 |
| P2-2 | Performance benchmarks      | 4          | P0-11        |
| P2-3 | Release automation workflow | 2          | P0-9         |
| P2-4 | Dependabot configuration    | 0.5        | None         |

**Total P2: ~7.5 hours**

---

## Risk Assessment

| Risk                                  | Likelihood | Impact | Mitigation                                        |
| ------------------------------------- | ---------- | ------ | ------------------------------------------------- |
| Cursor hook API changes               | Medium     | High   | Pin to Cursor 1.7+; document version requirements |
| Windsurf hook limitations             | High       | Medium | Accept enhanced basic mode; document workarounds  |
| OpenCode experimental API instability | Medium     | Medium | Use stable `chat.headers` where possible          |
| Test framework complexity             | Low        | Medium | Start with critical paths; expand incrementally   |
| Breaking changes during migration     | Low        | High   | Comprehensive dry-run testing; backup mechanism   |

---

## Success Criteria

### v0.5.0 Release Requirements

- [ ] All P0 tasks completed
- [ ] At least 80% of P1 tasks completed
- [ ] CI pipeline passing on main branch
- [ ] Test coverage >70% for hooks and plugin
- [ ] Cross-agent compatibility documented
- [ ] No duplicate file structure
- [ ] CHANGELOG.md current

### Feature Parity Targets

| Agent       | Collection | Injection   | Skill     | Target |
| ----------- | ---------- | ----------- | --------- | ------ |
| Claude Code | ✅ Auto    | ✅ Auto     | ✅ Full   | 100%   |
| OpenCode    | ✅ Auto    | ✅ Auto     | ✅ Full   | 95%    |
| Windsurf    | ✅ Auto    | ⚠️ Workflow | ⚠️ Reuse  | 75%    |
| Cursor      | ✅ Auto    | ❌ Manual   | ⚠️ Manual | 60%    |

---

## Timeline

```
Week 1 (Jan 27 - Jan 31): Phase 1 + Phase 2
  - Repository cleanup
  - GitHub infrastructure
  - Testing framework setup
  - CI/CD pipeline

Week 2 (Feb 3 - Feb 7): Phase 3 + Phase 4
  - Windsurf full-mode implementation
  - Cursor enhanced basic mode
  - Integration testing

Week 3 (Feb 10 - Feb 14): Phase 5 + Phase 6
  - OpenCode completion
  - Documentation
  - Release preparation
  - v0.5.0 release
```

---

## Appendix A: Research Sources

### Cursor

- [Cursor Docs: Hooks](https://cursor.com/docs/agent/hooks)
- [Cursor Docs: Rules](https://cursor.com/docs/context/rules)
- [InfoQ: Cursor 1.7 Hooks Overview](https://www.infoq.com/news/2025/10/cursor-hooks/)

### Windsurf

- [Cascade Hooks Documentation](https://docs.windsurf.com/windsurf/cascade/hooks)
- [Cascade Memories Documentation](https://docs.windsurf.com/windsurf/cascade/memories)
- [Windsurf Workflows Documentation](https://docs.windsurf.com/windsurf/cascade/workflows)

### OpenCode

- [OpenCode Plugins Documentation](https://opencode.ai/docs/plugins/)
- [OpenCode Releases - January 2026](https://github.com/anomalyco/opencode/releases)
- [OpenCode Session Metadata Plugin](https://github.com/crayment/opencode-session-metadata)

---

## Appendix B: Related Projects

### Cross-Agent Compatibility Engine (CACE)

The sibling project `../cross-agent-compatibility-engine` provides:

- Bidirectional component conversion between agents
- Canonical IR (ComponentSpec) for agent-agnostic representation
- Loss reporting and fidelity scoring
- CLI tools for conversion, validation, and inspection

Response Boxes can leverage CACE for:

- Converting skills between agents
- Documenting capability mappings
- Validating cross-agent compatibility

See: `docs/cross-agent-compatibility.md` for integration details.

---

## Changelog

| Date       | Author | Changes                                    |
| ---------- | ------ | ------------------------------------------ |
| 2026-01-24 | AI     | Initial draft based on comprehensive audit |
