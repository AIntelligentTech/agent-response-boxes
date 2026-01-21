# Claude Response Boxes

> A metacognitive annotation system for Claude Code — structured transparency
> into AI reasoning, decisions, and self-assessment.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-green.svg)](https://github.com/AIntelligentTech/claude-response-boxes/releases)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Compatible-blueviolet.svg)](https://claude.ai/claude-code)

---

## Highlights

- **Transparent Reasoning** — See Claude's choices, assumptions, and decisions
  inline
- **Anti-Sycophancy** — Built-in self-assessment prevents hollow validation
- **Task Completion Checks** — Forced reassessment ensures nothing is missed
- **Analytics Pipeline** — Track patterns across sessions with JSONL storage
- **Zero Config** — One-line install, works immediately
- **Git-Portable** — Context uses git remotes, not filesystem paths

---

## Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/AIntelligentTech/claude-response-boxes/main/install.sh | bash
```

Or clone and install locally:

```bash
git clone https://github.com/AIntelligentTech/claude-response-boxes.git
cd claude-response-boxes
./install.sh
```

**Requirements:** `jq` (for analytics), `bash 4+`

---

## What It Does

After installation, Claude Code annotates responses with structured "boxes":

```
⚖️ Choice ───────────────────────────────────────
**Selected:** Haiku model
**Alternatives:** Sonnet, Opus
**Reasoning:** Cost-effective for analysis-only task
────────────────────────────────────────────────
```

These boxes make AI reasoning **explicit and correctable**, rather than hidden
in prose.

---

## Box Types

### Inline Boxes (at point of relevance)

| Emoji | Type       | When to Use                      |
| ----- | ---------- | -------------------------------- |
| ⚖️    | Choice     | Selected between 2+ alternatives |
| 🎯    | Decision   | Made a judgment call             |
| 💭    | Assumption | Filled unstated requirement      |
| 📊    | Confidence | Claim with uncertainty (<90%)    |
| ↩️    | Pushback   | Disagrees with user direction    |
| ⚠️    | Concern    | Potential risk to flag           |
| 💡    | Suggestion | Optional improvement             |
| 🚨    | Warning    | Serious risk requiring attention |

### End-of-Response Boxes (max 3, in order)

| Emoji | Type       | When to Use                          |
| ----- | ---------- | ------------------------------------ |
| 📋    | Follow Ups | Next steps exist for user            |
| 🏁    | Completion | Task being completed (forces review) |
| ✅    | Quality    | Code was written                     |
| 🪞    | Sycophancy | **Always** (substantive responses)   |

---

## Why Use This?

| Problem                           | Solution                                    |
| --------------------------------- | ------------------------------------------- |
| "Why did it choose X?"            | ⚖️ Choice box explains alternatives weighed |
| "Did it assume Y?"                | 💭 Assumption box makes it explicit         |
| "Is this actually done?"          | 🏁 Completion forces reassessment           |
| "Is it just agreeing with me?"    | 🪞 Sycophancy self-check on every response  |
| "What patterns emerge over time?" | Analytics tracks box frequency by type/repo |

---

## Analytics

### Collection

Boxes are automatically collected to `~/.claude/analytics/boxes.jsonl`:

```json
{
  "ts": "2026-01-21T18:30:00Z",
  "type": "Choice",
  "fields": {
    "selected": "Haiku model",
    "alternatives": "Sonnet, Opus",
    "reasoning": "Cost-effective"
  },
  "context": {
    "session_id": "abc123",
    "git_remote": "github.com/org/repo",
    "git_branch": "main"
  }
}
```

### Analysis

```bash
# Full analysis
~/.claude/scripts/analyze-boxes.sh

# Last 7 days
~/.claude/scripts/analyze-boxes.sh -d 7

# Specific repo
~/.claude/scripts/analyze-boxes.sh -r github.com/org/repo

# JSON output for pipelines
~/.claude/scripts/analyze-boxes.sh -j | jq .
```

### Key Metrics

| Metric                  | Insight                                  |
| ----------------------- | ---------------------------------------- |
| Confidence distribution | Consistently uncertain or overconfident? |
| Assumption frequency    | What gets assumed most often?            |
| Pushback rate           | Is Claude challenging appropriately?     |
| Sycophancy scores       | Tracking anti-sycophancy compliance      |
| Completion confidence   | Task reassessment quality over time      |

---

## Configuration

### Custom Analytics Location

```bash
export BOX_ANALYTICS_FILE=~/my-analytics/boxes.jsonl
```

### Project ID for Non-Git Directories

```bash
export PROJECT_ID="my-project-name"
```

### Manual Hook Setup

If automatic collection isn't working, add to your Claude Code hooks:

```yaml
# ~/.claude/hooks.yaml
post_message:
  - command: ~/.claude/hooks/collect-boxes.sh
    input: response
```

---

## File Structure

```
~/.claude/
├── rules/
│   └── response-boxes.md      # Full specification (read by Claude)
├── hooks/
│   └── collect-boxes.sh       # Parses responses → JSONL
├── scripts/
│   └── analyze-boxes.sh       # Pattern analysis
└── analytics/
    └── boxes.jsonl            # Collected data
```

---

## Design Philosophy

### Git-Based Context

Context uses **git remotes** instead of filesystem paths:

| Problem                                    | Solution                             |
| ------------------------------------------ | ------------------------------------ |
| `/Users/alice/my-app` ≠ `/home/bob/my-app` | `github.com/org/my-app` is universal |
| Path leaks local structure                 | Git remote is public anyway          |
| Breaks when repo moves                     | Remote stays consistent              |

### Verbosity Preference

> **Prefer more boxes over fewer** — missing context is worse than noise.

If in doubt whether to include a box, include it.

### End Box Limit

Maximum 3 end boxes to prevent wall-of-boxes syndrome:

1. 📋 Follow Ups (if applicable)
2. 🏁 Completion (if completing task)
3. 🪞 Sycophancy (always last)

---

## Contributing

Contributions welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for
guidelines.

**Quick start:**

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-box`)
3. Commit changes (`git commit -m 'Add amazing box type'`)
4. Push to branch (`git push origin feature/amazing-box`)
5. Open a Pull Request

---

## License

[MIT](LICENSE) — Use freely, attribution appreciated.

---

## Acknowledgments

- Inspired by structured thinking frameworks and metacognitive research
- Built for use with [Claude Code](https://claude.ai/claude-code) by Anthropic

---

<p align="center">
  <sub>Made with care by <a href="https://github.com/AIntelligentTech">AIntelligentTech</a></sub>
</p>
