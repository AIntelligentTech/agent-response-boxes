# Claude Response Boxes

> A metacognitive annotation system for Claude Code — structured transparency
> into AI reasoning, decisions, and self-assessment with **active enforcement**.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-2.0.0-green.svg)](https://github.com/AIntelligentTech/claude-response-boxes/releases)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Compatible-blueviolet.svg)](https://claude.ai/claude-code)

---

## What's New in v2.0

**Active enforcement replaces passive documentation.** Response quality is now
ENFORCED via hooks, not just requested.

| v1.x (Passive)            | v2.0 (Active)                         |
| ------------------------- | ------------------------------------- |
| Rules in CLAUDE.md        | Rules + Stop hook validation          |
| Claude may forget         | Hooks block incomplete responses      |
| Manual box collection     | Auto-scoring and indexing             |
| No cross-session learning | Prior boxes injected at session start |

---

## Highlights

- **Enforced Compliance** — Stop hook blocks responses missing required boxes
- **Transparent Reasoning** — See choices, assumptions, decisions inline
- **Anti-Sycophancy** — Built-in self-assessment prevents hollow validation
- **Self-Improvement Loop** — Session-end analysis with headless Claude
- **Cross-Session Learning** — High-value boxes injected at session start
- **Box Scoring** — Prioritize important learnings automatically
- **Zero Config** — One-line install, works immediately

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           RESPONSE BOX LIFECYCLE v2.0                               │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  SESSION START                                                                      │
│  ┌───────────────────────────────────────────────────────────────────────────────┐ │
│  │  inject-context.sh loads high-value prior boxes from box-index.json           │ │
│  └───────────────────────────────────────────────────────────────────────────────┘ │
│                                       │                                             │
│                                       ▼                                             │
│  DURING SESSION                                                                     │
│  ┌───────────────────────────────────────────────────────────────────────────────┐ │
│  │  1. CLAUDE.md pre-response checklist guides box usage                         │ │
│  │  2. enforce-reminder.sh injects reminders every 3rd tool call                 │ │
│  │  3. collect-boxes.sh parses responses → boxes.jsonl                           │ │
│  └───────────────────────────────────────────────────────────────────────────────┘ │
│                                       │                                             │
│                                       ▼                                             │
│  STOP (before completion)                                                           │
│  ┌───────────────────────────────────────────────────────────────────────────────┐ │
│  │  validate-response.sh:                                                        │ │
│  │  • Substantive response (>300 chars)? Check for 🪞 Sycophancy box            │ │
│  │  • No reasoning patterns AND no inline boxes? BLOCK with feedback            │ │
│  │  • Missing required elements? Exit code 2 → Claude must fix                  │ │
│  └───────────────────────────────────────────────────────────────────────────────┘ │
│                                       │                                             │
│                                       ▼                                             │
│  SESSION END                                                                        │
│  ┌───────────────────────────────────────────────────────────────────────────────┐ │
│  │  session-end-analyze.sh:                                                      │ │
│  │  • Score boxes by importance (type, context, recency)                        │ │
│  │  • Update box-index.json with high-value boxes (score ≥60)                   │ │
│  │  • Optional: Run headless Claude for deep pattern analysis                   │ │
│  └───────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

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

**Requirements:** `jq` (for analytics and hook configuration), `bash 4+`

### Installation Options

```bash
./install.sh              # Full installation
./install.sh --no-hooks   # Rules only (no enforcement)
./install.sh --hooks-only # Hooks only (skip rules)
./install.sh --uninstall  # Remove components
```

---

## What It Does

After installation, Claude Code responses are ENFORCED to include structured
boxes:

```
⚖️ Choice ───────────────────────────────────────
**Selected:** Haiku model
**Alternatives:** Sonnet, Opus
**Reasoning:** Cost-effective for analysis-only task
────────────────────────────────────────────────
```

**If you forget a required box, the Stop hook blocks completion:**

```
═══════════════════════════════════════════════════════════════
  RESPONSE VALIDATION FAILED
═══════════════════════════════════════════════════════════════

Missing required elements:
  ✗ 🪞 Sycophancy box (required for all substantive responses)

Add the missing elements before completing your response.
═══════════════════════════════════════════════════════════════
```

---

## Box Types

### Inline Boxes (at point of relevance)

| Emoji | Type       | When to Use                      |
| ----- | ---------- | -------------------------------- |
| ⚖️    | Choice     | Selected between 2+ alternatives |
| 🎯    | Decision   | Made a judgment call             |
| 💭    | Assumption | Filled unstated requirement      |
| 🔄    | Reflection | Applied learning from prior box  |
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

## Box Scoring System

Boxes are scored by importance for prioritization and context injection:

| Box Type      | Base Score | High-Value Triggers            |
| ------------- | ---------- | ------------------------------ |
| 🔄 Reflection | 90         | References a correction        |
| 🚨 Warning    | 90         | Always high (safety)           |
| ↩️ Pushback   | 85         | Shows healthy challenge        |
| 💭 Assumption | 80         | User corrected it (+30)        |
| ⚖️ Choice     | 70         | User chose differently (+25)   |
| 🏁 Completion | 70         | Has gaps or improvements (+20) |

**Context multipliers:** Same repo (1.5x), Last 7 days (1.3x), Part of
correction sequence (1.6x)

Customize weights in `~/.claude/config/scoring-weights.json`.

---

## Self-Improvement Loop

### Session-End Analysis

When Claude Code stops, `session-end-analyze.sh` automatically:

1. Extracts boxes from the session
2. Scores each by importance
3. Updates `box-index.json` with high-value boxes
4. Optionally runs headless Claude for deep analysis

**Enable deep analysis:**

```bash
export BOX_DEEP_ANALYSIS=true
```

### Session-Start Injection

When a new session starts, `inject-context.sh`:

1. Loads high-value boxes from the index
2. Prioritizes boxes from the same repository
3. Injects them as context (e.g., prior assumptions, corrections)

**Disable injection:**

```bash
export BOX_INJECT_DISABLED=true
```

---

## Analytics

### Manual Analysis

```bash
# Full analysis
~/.claude/scripts/analyze-boxes.sh

# Last 7 days
~/.claude/scripts/analyze-boxes.sh -d 7

# Specific repo
~/.claude/scripts/analyze-boxes.sh -r github.com/org/repo

# JSON output
~/.claude/scripts/analyze-boxes.sh -j | jq .
```

### Backfill Unscored Boxes

```bash
~/.claude/scripts/session-end-analyze.sh --all
```

### Key Metrics

| Metric                  | Insight                                  |
| ----------------------- | ---------------------------------------- |
| Confidence distribution | Consistently uncertain or overconfident? |
| Assumption frequency    | What gets assumed most often?            |
| Pushback rate           | Is Claude challenging appropriately?     |
| Sycophancy scores       | Tracking anti-sycophancy compliance      |
| Completion confidence   | Task reassessment quality                |

---

## File Structure

```
~/.claude/
├── rules/
│   └── response-boxes.md          # Full specification with enforcement
├── hooks/
│   ├── collect-boxes.sh           # Parse responses → boxes.jsonl
│   ├── validate-response.sh       # Stop hook validation
│   ├── enforce-reminder.sh        # PostToolUse reminder injection
│   └── inject-context.sh          # SessionStart context injection
├── scripts/
│   ├── analyze-boxes.sh           # Interactive analysis
│   ├── score-boxes.sh             # Score boxes by importance
│   └── session-end-analyze.sh     # Session-end analysis + indexing
├── config/
│   └── scoring-weights.json       # Customizable scoring weights
└── analytics/
    ├── boxes.jsonl                # Raw box storage
    ├── box-index.json             # High-value box index
    └── session-analyses.jsonl     # Deep analysis results
```

---

## Configuration

### Environment Variables

| Variable                | Default                           | Description                        |
| ----------------------- | --------------------------------- | ---------------------------------- |
| `BOX_ANALYTICS_FILE`    | `~/.claude/analytics/boxes.jsonl` | Override storage location          |
| `BOX_VALIDATION_STRICT` | `false`                           | Require reasoning in all responses |
| `BOX_DEEP_ANALYSIS`     | `false`                           | Enable headless Claude analysis    |
| `BOX_INJECT_DISABLED`   | `false`                           | Disable session-start injection    |
| `BOX_INJECT_COUNT`      | `5`                               | Number of boxes to inject          |

### Manual Hook Configuration

If auto-configuration fails, add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/validate-response.sh",
            "timeout": 5
          },
          {
            "type": "command",
            "command": "~/.claude/scripts/session-end-analyze.sh -q",
            "timeout": 30
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/enforce-reminder.sh",
            "timeout": 2
          }
        ]
      }
    ]
  }
}
```

---

## Contributing

Contributions welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md).

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
