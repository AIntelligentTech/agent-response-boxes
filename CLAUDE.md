# Response Boxes - Project Instructions

**Version:** 0.6.0 **Type:** Multi-agent metacognitive annotation system

---

## Project Overview

Response Boxes is a metacognitive annotation system for AI coding agents that:

1. **Surfaces hidden reasoning** — Choices, assumptions, and decisions are
   explicitly documented
2. **Enables within-session self-reflection** — Agents audit their own work
   before completing tasks
3. **Supports cross-session learning** — High-value boxes become evidence for
   synthesized learnings that persist across sessions

### Supported Agents

| Agent       | Collection    | Injection         | Analysis       |
| ----------- | ------------- | ----------------- | -------------- |
| Claude Code | Hook (auto)   | Hook (auto)       | Skill (native) |
| OpenCode    | Plugin (auto) | Plugin (auto)     | Skill (native) |
| Windsurf    | Hook (auto)   | Workflow (manual) | Skill (reuse)  |
| Cursor      | Hook (auto)   | Skill (manual)    | Skill (reuse)  |

---

## Directory Structure

```
agents/
├── claude-code/           # Reference implementation (full support)
│   ├── config/            # CLAUDE.md snippet
│   ├── hooks/             # SessionStart/SessionEnd hooks
│   ├── output-styles/     # response-box.md output style
│   ├── rules/             # response-boxes.md, anti-sycophancy.md
│   └── skills/            # /analyze-boxes skill
├── cursor/                # Cursor integration (basic support)
│   ├── hooks/             # cursor-collector.sh
│   ├── rules/             # response-boxes.mdc
│   └── skills/            # /response-boxes-context skill
├── opencode/              # OpenCode integration (full support)
│   ├── instructions/      # response-boxes.md
│   ├── plugins/           # response-boxes.plugin.ts
│   └── skills/            # /analyze-boxes skill
└── windsurf/              # Windsurf integration (enhanced support)
    ├── hooks/             # windsurf-collector.sh, hooks.json
    ├── rules/             # response-boxes.md
    └── workflows/         # response-boxes-start.md

docs/
├── architecture.md        # Technical architecture and data structures
└── cross-agent-compatibility.md  # Agent capability matrices

tests/
├── fixtures/              # Sample transcript and box data
├── hooks/                 # Hook tests (bats)
└── test_helper.bash       # Test utilities

install.sh                 # Universal installer script
```

---

## Key Files

### Core Specification

- `agents/claude-code/rules/response-boxes.md` — Complete box taxonomy and usage
  guidelines (12 box types)
- `agents/claude-code/rules/anti-sycophancy.md` — Research-backed internal
  protocol for preventing sycophantic behavior (v0.6.0)
- `agents/claude-code/output-styles/response-box.md` — Active output style for
  Claude Code sessions

### Hooks (Data Persistence)

- `agents/claude-code/hooks/inject-context.sh` — SessionStart: loads prior
  learnings and high-value boxes from event store
- `agents/claude-code/hooks/session-processor.sh` — SessionEnd: parses
  transcript for boxes and emits BoxCreated events

### Skills

- `agents/claude-code/skills/analyze-boxes/SKILL.md` — AI-powered pattern
  analysis that synthesizes learnings from boxes

### Installer

- `install.sh` — Universal installer with options for user/project scope,
  multi-agent support, dry-run, and force modes

---

## Development Guidelines

### Code Standards

- Shell scripts: Use `set -euo pipefail`, pass `shellcheck`
- JSON processing: Use `jq` for all JSON manipulation
- Event store: Append-only JSONL at `~/.response-boxes/analytics/boxes.jsonl`

### Box Format (Canonical)

```
[emoji] [Type] ─────────────────────────────────
**Field1:** Value
**Field2:** Value
────────────────────────────────────────────────
```

- 45 dashes (fits 80-char terminals)
- Keep boxes concise

### Event Types

| Event           | Description                         | Source         |
| --------------- | ----------------------------------- | -------------- |
| BoxCreated      | Raw box captured from transcript    | Hooks/plugins  |
| BoxEnriched     | User/system added metadata to box   | Analysis       |
| LearningCreated | Synthesized pattern from evidence   | /analyze-boxes |
| EvidenceLinked  | Box linked as evidence for learning | /analyze-boxes |
| LearningUpdated | Confidence or description updated   | /analyze-boxes |
| LearningLinked  | Learning linked to meta-learning    | /analyze-boxes |

### Testing

```bash
# Validate shell script syntax
bash -n install.sh
bash -n agents/claude-code/hooks/*.sh

# Validate JSON fixtures
jq . tests/fixtures/sample-transcript.json
while IFS= read -r line; do echo "$line" | jq . > /dev/null; done < tests/fixtures/sample-boxes.jsonl

# Run bats tests (if installed)
bats tests/hooks/
```

### Commits

Follow conventional commits:

- `feat(v0.X.0):` — New feature for a version
- `fix(installer):` — Bug fix in installer
- `docs:` — Documentation updates
- `refactor:` — Code refactoring
- `test:` — Test additions/updates

---

## v0.6.0 Changes (Current)

### Breaking Changes

- **Removed 🪞 Sycophancy box** from response box taxonomy
- Anti-sycophancy is now an internal protocol (no visible output)

### Key Files Changed

- `agents/claude-code/rules/response-boxes.md` — Removed Sycophancy spec
- `agents/claude-code/rules/anti-sycophancy.md` — NEW: Research-backed protocol
- `agents/claude-code/hooks/inject-context.sh` — Filters Sycophancy boxes
- `agents/claude-code/hooks/session-processor.sh` — Removed Sycophancy scoring
- All agent rules files updated

### Anti-Sycophancy Protocol

Based on peer-reviewed research:

- **ELEPHANT Framework** — Five dimensions of social sycophancy
- **SMART Framework** — System 2 thinking reduces sycophancy 31-46%
- **Self-Blinding Research** — Counterfactual checking reveals knowing
  sycophancy

Key techniques:

- System 2 self-interrogation (challenge detection, counterfactual check)
- Third-person perspective (63.8% reduction)
- Banned phrases ("You're absolutely right!", "Great question!", etc.)

---

## Release Process

1. Update version in:
   - `install.sh` (VERSION variable)
   - `README.md` (badge)
   - `docs/architecture.md` (header and changelog)

2. Update `CHANGELOG.md` with release notes

3. Commit with message: `feat(vX.Y.Z): Description`

4. Create annotated tag: `git tag -a vX.Y.Z -m "Release notes"`

5. Push: `git push origin main && git push origin vX.Y.Z`

---

## Common Tasks

### Adding a New Box Type

1. Add spec to `agents/claude-code/rules/response-boxes.md`
2. Add to output style `agents/claude-code/output-styles/response-box.md`
3. Add emoji mapping to `agents/claude-code/hooks/session-processor.sh`
4. Add initial score to `session-processor.sh` INITIAL_SCORES array
5. Update other agent rules (windsurf, cursor, opencode)
6. Update tests and fixtures

### Adding a New Agent

1. Create `agents/<agent-name>/` directory structure
2. Adapt hooks/plugins for agent's extension model
3. Create rules file with agent-appropriate format
4. Add to installer if applicable
5. Update `docs/cross-agent-compatibility.md`
6. Update README.md compatibility table

### Modifying the Installer

1. Test with `--dry-run` first
2. Ensure idempotency (re-running is safe)
3. Update `is_local_source_dir()` if adding new required files
4. Update uninstall list if adding new installed files
5. Validate syntax: `bash -n install.sh`

---

## References

- [ELEPHANT Framework](https://arxiv.org/html/2505.13995v2) — Social sycophancy
- [SMART Framework](https://arxiv.org/html/2509.16742v1) — System 2 thinking
- [Anthropic Sycophancy Study](https://arxiv.org/abs/2310.13548) — RLHF effects
- [Self-Blinding Research](https://arxiv.org/html/2601.14553) — Counterfactual
  detection
