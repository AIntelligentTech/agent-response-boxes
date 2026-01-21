# Response Box System v2.0 Architecture

## Overview

This document defines the complete enforcement and self-improvement architecture
for the Response Box System.

---

## System Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           RESPONSE BOX LIFECYCLE                                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  SESSION START                                                                       │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │  1. SessionStart hook triggers inject-context.sh                             │   │
│  │  2. Load high-value boxes from index (~/.claude/analytics/box-index.json)    │   │
│  │  3. Inject as context: prior assumptions, corrections, preferences           │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                       │                                              │
│                                       ▼                                              │
│  DURING SESSION                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │  CLAUDE.md ACTIVE ENFORCEMENT                                                │   │
│  │  ┌─────────────────────────────────────────────────────────────────────┐    │   │
│  │  │  Pre-response checklist (in CLAUDE.md):                             │    │   │
│  │  │  □ Did I select between alternatives? → ⚖️ Choice                    │    │   │
│  │  │  □ Did I make a judgment call? → 🎯 Decision                         │    │   │
│  │  │  □ Did I fill unstated requirements? → 💭 Assumption                 │    │   │
│  │  │  □ Is this substantive? → 🪞 Sycophancy at end                       │    │   │
│  │  │  □ Did I explain WHY, not just WHAT?                                 │    │   │
│  │  └─────────────────────────────────────────────────────────────────────┘    │   │
│  │                                                                              │   │
│  │  POST-TOOL-USE CONTEXT INJECTION (every tool call)                          │   │
│  │  ┌─────────────────────────────────────────────────────────────────────┐    │   │
│  │  │  additionalContext: "REMINDER: Include response boxes and reasoning" │    │   │
│  │  └─────────────────────────────────────────────────────────────────────┘    │   │
│  │                                                                              │   │
│  │  RESPONSE GENERATION                                                         │   │
│  │  ┌─────────────────────────────────────────────────────────────────────┐    │   │
│  │  │  Claude generates response with boxes based on CLAUDE.md rules       │    │   │
│  │  └─────────────────────────────────────────────────────────────────────┘    │   │
│  │                                       │                                      │   │
│  │                                       ▼                                      │   │
│  │  BOX COLLECTION (PostToolUse hook on all tools)                             │   │
│  │  ┌─────────────────────────────────────────────────────────────────────┐    │   │
│  │  │  collect-boxes.sh parses response → appends to boxes.jsonl           │    │   │
│  │  └─────────────────────────────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                       │                                              │
│                                       ▼                                              │
│  STOP HOOK (before Claude completes)                                                │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │  validate-response.sh:                                                       │   │
│  │  1. Check if response is substantive (>300 chars, not simple confirmation)  │   │
│  │  2. If substantive: verify required boxes present                           │   │
│  │  3. If missing: exit 2 with feedback → Claude must fix                      │   │
│  │  4. If compliant: exit 0 → allow completion                                 │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                       │                                              │
│                                       ▼                                              │
│  SESSION END                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │  session-end-analyze.sh:                                                     │   │
│  │  1. Extract boxes from this session                                         │   │
│  │  2. Score each box by importance                                            │   │
│  │  3. Detect patterns and violations                                          │   │
│  │  4. Update box-index.json with high-value boxes                             │   │
│  │  5. Optionally: run headless Claude for deeper analysis                     │   │
│  │  6. Backfill any unscored boxes from previous sessions                      │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Specifications

### 1. Stop Hook: validate-response.sh

**Purpose:** Enforce response quality BEFORE Claude completes

**Decision:** Use command-type hook (not prompt-type) because:

- Command hooks can read transcript to see actual response
- Command hooks can apply deterministic validation rules
- Command hooks can reference the rules file for criteria

**Implementation:**

```bash
#!/usr/bin/env bash
# validate-response.sh - Stop hook for response validation

# Read last assistant message from transcript
TRANSCRIPT="${CLAUDE_TRANSCRIPT_PATH:-}"
if [[ -z "$TRANSCRIPT" ]] || [[ ! -f "$TRANSCRIPT" ]]; then
    exit 0  # Can't validate, allow completion
fi

LAST_RESPONSE=$(jq -r '
    [.[] | select(.type == "assistant")] | last | .content // ""
' "$TRANSCRIPT")

# Skip validation for short responses (confirmations, file reads)
CHAR_COUNT=${#LAST_RESPONSE}
if [[ $CHAR_COUNT -lt 300 ]]; then
    exit 0
fi

# Check for required boxes in substantive responses
MISSING=""

# Check for Sycophancy box (always required for substantive)
if ! echo "$LAST_RESPONSE" | grep -q "🪞"; then
    MISSING="${MISSING}🪞 Sycophancy (required for all substantive responses)\n"
fi

# Check if reasoning is present (not just actions)
# Look for explanation patterns: "because", "since", "reason", etc.
if ! echo "$LAST_RESPONSE" | grep -qiE "(because|since|reason|therefore|this means|in order to)"; then
    MISSING="${MISSING}Reasoning explanation (explain WHY, not just WHAT)\n"
fi

if [[ -n "$MISSING" ]]; then
    echo "VALIDATION FAILED - Response missing required elements:"
    echo -e "$MISSING"
    echo ""
    echo "Add the missing elements before completing."
    exit 2  # Block completion
fi

exit 0  # Allow completion
```

**Hook Configuration:**

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
          }
        ]
      }
    ]
  }
}
```

---

### 2. Box Scoring System

**Purpose:** Prioritize boxes by importance for efficient context injection

**Scoring Weights:**

| Box Type      | Base Score | Multipliers                               |
| ------------- | ---------- | ----------------------------------------- |
| 🔄 Reflection | 90         | +20 if references correction              |
| 💭 Assumption | 80         | +30 if user corrected, -20 if routine     |
| ⚖️ Choice     | 70         | +25 if user chose differently             |
| 🏁 Completion | 70         | +20 if has gaps, +15 if has improvements  |
| 📊 Confidence | 60         | +30 if was wrong (< predicted level)      |
| 🪞 Sycophancy | 50         | +40 if rating < 7 (needs improvement)     |
| ↩️ Pushback   | 85         | Always valuable (shows healthy challenge) |
| ⚠️ Concern    | 65         | +20 if later validated                    |
| 🚨 Warning    | 90         | Always high (safety)                      |
| 🎯 Decision   | 55         | +15 if affected outcome                   |
| 💡 Suggestion | 45         | +25 if user adopted                       |
| ✅ Quality    | 40         | +20 if rating < 7 (learning opportunity)  |
| 📋 Follow Ups | 35         | Low (transient)                           |

**Context Multipliers:**

| Factor                      | Multiplier |
| --------------------------- | ---------- |
| Same repository             | 1.5x       |
| Last 7 days                 | 1.3x       |
| Last 30 days                | 1.1x       |
| Has user follow-up          | 1.4x       |
| Part of correction sequence | 1.6x       |

**Scoring Algorithm:**

```
final_score = base_score * type_multipliers * context_multipliers * recency_decay
recency_decay = 1.0 - (days_old / 90) * 0.5  # 50% decay over 90 days
```

---

### 3. Session-End Analysis: session-end-analyze.sh

**Purpose:** Analyze session, score boxes, update index, optionally run headless
Claude

**Components:**

1. **Extract session boxes** from boxes.jsonl
2. **Score each box** using scoring weights
3. **Detect patterns:**
   - Missing required boxes (compliance rate)
   - Low sycophancy scores (sycophancy issues)
   - Frequent assumption types (behavioral patterns)
   - Correction sequences (learning opportunities)
4. **Update box-index.json** with high-value boxes (score > 60)
5. **Optional: Headless Claude analysis** for deeper insights

**Headless Claude Integration:**

```bash
# Only run for sessions with > 10 boxes or violations detected
if [[ $BOX_COUNT -gt 10 ]] || [[ $VIOLATIONS -gt 0 ]]; then
    ANALYSIS=$(claude --print --max-turns 1 "
Analyze these response boxes from a Claude Code session:

$(cat /tmp/session-boxes.json)

Identify:
1. Patterns in assumptions made
2. Areas where reasoning was insufficient
3. Suggestions for CLAUDE.md rule updates
4. Any concerning trends

Output as JSON with keys: patterns, reasoning_gaps, rule_suggestions, concerns
")
    echo "$ANALYSIS" >> ~/.claude/analytics/session-analyses.jsonl
fi
```

---

### 4. Session-Start Context Injection: inject-context.sh

**Purpose:** Load high-value prior boxes into session context

**Implementation:**

```bash
#!/usr/bin/env bash
# inject-context.sh - SessionStart hook for context injection

INDEX_FILE="${HOME}/.claude/analytics/box-index.json"
CONTEXT_LIMIT=5  # Max boxes to inject

if [[ ! -f "$INDEX_FILE" ]]; then
    exit 0
fi

# Get current repo (if in git directory)
CURRENT_REPO=""
if git rev-parse --git-dir &>/dev/null; then
    CURRENT_REPO=$(git remote get-url origin 2>/dev/null | sed -E 's|^(https?://\|git@)||; s|:|/|; s|\.git$||')
fi

# Query high-value boxes, prioritize same repo
RELEVANT_BOXES=$(jq -r --arg repo "$CURRENT_REPO" '
    .boxes
    | map(select(.score > 60))
    | map(. + {relevance: (if .context.git_remote == $repo then 1.5 else 1.0 end) * .score})
    | sort_by(-.relevance)
    | .[0:5]
    | map("- \(.type): \(.fields | to_entries | map("\(.key): \(.value)") | join(", "))")
    | join("\n")
' "$INDEX_FILE")

if [[ -n "$RELEVANT_BOXES" ]]; then
    echo "PRIOR SESSION CONTEXT (high-value learnings):"
    echo "$RELEVANT_BOXES"
fi

exit 0
```

---

### 5. Data Structures

**boxes.jsonl (existing, unchanged):**

```json
{
  "ts": "2026-01-21T18:30:00Z",
  "type": "Assumption",
  "fields": {
    "what": "User wants TypeScript",
    "basis": "Project has tsconfig"
  },
  "context": {
    "session_id": "abc123",
    "git_remote": "github.com/org/repo",
    "git_branch": "main",
    "turn_number": 5
  }
}
```

**box-index.json (new - high-value box index):**

```json
{
  "version": "2.0.0",
  "last_updated": "2026-01-21T20:00:00Z",
  "boxes": [
    {
      "id": "box_abc123_5",
      "ts": "2026-01-21T18:30:00Z",
      "type": "Assumption",
      "fields": {
        "what": "User wants TypeScript",
        "basis": "Project has tsconfig"
      },
      "context": {
        "session_id": "abc123",
        "git_remote": "github.com/org/repo"
      },
      "score": 85,
      "score_breakdown": { "base": 80, "correction": 30, "recency": 0.95 },
      "correction_sequence": ["box_abc123_6"],
      "tags": ["technology-preference", "corrected"]
    }
  ],
  "statistics": {
    "total_processed": 150,
    "total_indexed": 45,
    "compliance_rate": 0.87,
    "avg_sycophancy_score": 8.5
  }
}
```

**session-analyses.jsonl (new - headless Claude analyses):**

```json
{
  "ts": "2026-01-21T20:00:00Z",
  "session_id": "abc123",
  "patterns": ["frequently assumes TypeScript", "tends to over-engineer"],
  "reasoning_gaps": ["didn't explain choice of library"],
  "rule_suggestions": ["Add explicit technology confirmation for new projects"],
  "concerns": []
}
```

---

### 6. CLAUDE.md Active Enforcement Section

**Replace passive rules with active checklist:**

```markdown
## Response Box System (MANDATORY)

**Full spec:** `~/.claude/rules/response-boxes.md`

### PRE-RESPONSE CHECKLIST (Complete BEFORE finalizing ANY substantive response)

**STOP. Before you finish this response, verify:**

1. □ **Did I select between alternatives?** → If yes: Add ⚖️ Choice box with
   Selected, Alternatives, Reasoning

2. □ **Did I make a judgment call without clear alternatives?** → If yes: Add 🎯
   Decision box with What, Reasoning

3. □ **Did I fill in something the user didn't specify?** → If yes: Add 💭
   Assumption box with What, Basis

4. □ **Did I explain WHY, not just WHAT?** → If not: Add reasoning. "I did X
   because Y" not just "I did X"

5. □ **Is this a substantive response (>300 chars, not a simple confirmation)?**
   → If yes: Add 🪞 Sycophancy box at end

**FAILURE TO COMPLETE THIS CHECKLIST = INCOMPLETE RESPONSE**

The Stop hook will block completion if required elements are missing.
```

---

### 7. File Structure

```
~/.claude/
├── rules/
│   └── response-boxes.md          # Full specification with enforcement
├── hooks/
│   ├── collect-boxes.sh           # Parse responses → boxes.jsonl
│   ├── validate-response.sh       # Stop hook validation
│   ├── inject-context.sh          # SessionStart context injection
│   └── enforce-reminder.sh        # PostToolUse reminder injection
├── scripts/
│   ├── analyze-boxes.sh           # Interactive analysis (existing)
│   ├── score-boxes.sh             # Score boxes by importance
│   ├── session-end-analyze.sh     # Session-end analysis + scoring
│   └── prune-boxes.sh             # Clean old/low-value boxes
├── analytics/
│   ├── boxes.jsonl                # Raw box storage
│   ├── box-index.json             # High-value box index
│   └── session-analyses.jsonl     # Headless Claude analyses
└── config/
    └── scoring-weights.json       # Customizable scoring weights
```

---

## Implementation Priority

| Priority | Component                  | Reason                 |
| -------- | -------------------------- | ---------------------- |
| 1        | validate-response.sh       | Immediate enforcement  |
| 2        | CLAUDE.md active checklist | Behavioral foundation  |
| 3        | response-boxes.md update   | Rule clarity           |
| 4        | score-boxes.sh             | Enable prioritization  |
| 5        | session-end-analyze.sh     | Close the loop         |
| 6        | inject-context.sh          | Cross-session learning |
| 7        | install.sh update          | Distribution           |
| 8        | Documentation              | Maintainability        |

---

## Changelog

- **v2.0.0** (2026-01-21): Complete enforcement architecture
  - Added Stop hook validation
  - Added box scoring system
  - Added session-end analysis with headless Claude
  - Added session-start context injection
  - Converted CLAUDE.md to active checklist
