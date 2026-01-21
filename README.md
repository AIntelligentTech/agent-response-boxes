# Claude Response Boxes

> A metacognitive annotation system for Claude Code — structured transparency
> into AI reasoning, decisions, and self-assessment.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-3.0.0-green.svg)](https://github.com/AIntelligentTech/claude-response-boxes/releases)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Compatible-blueviolet.svg)](https://claude.ai/claude-code)

---

## What Are Response Boxes?

Response boxes are structured annotations that make AI reasoning transparent.
Instead of hidden decision-making, every significant choice, assumption, and
judgment is explicitly documented.

**Before:**

```
I'll help you add input validation. Let me read the file...
[Read tool]
Now I can see the form. I'll add validation...
[Edit tool]
Successfully added validation to your login form!
```

**After:**

```
[Tools execute silently]

## Login Form Validation

**Summary:** Added Zod-based validation to LoginForm.tsx

**File Changes:**
- `src/components/LoginForm.tsx:15-42` — Validation schema
- `src/components/LoginForm.tsx:58-71` — Form resolver

⚖️ Choice ─────────────────────────────────────
**Selected:** Zod over Yup
**Alternatives:** Yup, manual validation
**Reasoning:** Better TypeScript inference, smaller bundle
────────────────────────────────────────────────

🏁 Completion ─────────────────────────────────
**Request:** Add input validation to login form
**Completed:** Email + password validation with inline errors
**Confidence:** 9/10
**Gaps:** No server-side validation
────────────────────────────────────────────────

🪞 Sycophancy ─────────────────────────────────
**Rating:** 10/10
**Check:** Factual summary, no celebratory language
────────────────────────────────────────────────
```

---

## Key Principles

| Principle                 | Description                                   |
| ------------------------- | --------------------------------------------- |
| **Silent Execution**      | No tool announcements or running commentary   |
| **Verbose Completion**    | Comprehensive technical summary at task end   |
| **Transparent Reasoning** | Choices, assumptions, decisions made explicit |
| **Anti-Sycophancy**       | No hollow validation or celebratory language  |
| **Self-Assessment**       | Mandatory reflection on response quality      |

---

## Box Types

### Inline Boxes (at point of relevance)

| Box           | When                        | Fields                            |
| ------------- | --------------------------- | --------------------------------- |
| ⚖️ Choice     | Selected between 2+ options | Selected, Alternatives, Reasoning |
| 🎯 Decision   | Made a judgment call        | What, Reasoning                   |
| 💭 Assumption | Filled unstated requirement | What, Basis                       |
| ⚠️ Concern    | Potential risk to flag      | Issue, Impact, Mitigation         |
| 🚨 Warning    | Serious risk                | Risk, Likelihood, Consequence     |
| 📊 Confidence | Uncertainty <90%            | Claim, Level (X/10), Basis        |
| ↩️ Pushback   | Disagree with direction     | Position, Reasoning               |
| 💡 Suggestion | Optional improvement        | Idea, Benefit                     |
| 🔄 Reflection | Applied prior learning      | Prior, Learning, Application      |

### End Boxes (max 3, in this order)

| Box           | When                     | Fields                                        |
| ------------- | ------------------------ | --------------------------------------------- |
| 📋 Follow Ups | Next steps exist         | Immediate, Consider, Related                  |
| 🏁 Completion | Task being completed     | Request, Completed, Confidence, Gaps, Improve |
| ✅ Quality    | Code was written         | Rating (X/10), Justification                  |
| 🪞 Sycophancy | **Always** (substantive) | Rating (X/10), Check                          |

### Box Format

```
[emoji] [Type] ─────────────────────────────────
**Field1:** Value
**Field2:** Value
────────────────────────────────────────────────
```

---

## Pre-Response Checklist

Before completing any substantive response:

```
[] Selected between alternatives?     → ⚖️ Choice box
[] Made a judgment call?              → 🎯 Decision box
[] Filled unstated requirement?       → 💭 Assumption box
[] Task being completed?              → 🏁 Completion box
[] Substantive response (>300 chars)? → 🪞 Sycophancy box (ALWAYS)
```

---

## When to Use Each Box

### Always Required

- 🪞 **Sycophancy** — Every substantive response
- 🏁 **Completion** — Every task completion

### Use When Applicable

- ⚖️ **Choice** — Selecting between viable alternatives
- 🎯 **Decision** — Judgment calls without clear alternatives
- 💭 **Assumption** — Filling in unstated requirements
- ⚠️ **Concern** — Flagging potential issues

### Use When Needed

- 📊 **Confidence** — Claims with meaningful uncertainty
- ↩️ **Pushback** — Genuine disagreement with direction
- 💡 **Suggestion** — Optional improvements not requested
- 🚨 **Warning** — Serious risks requiring attention
- 🔄 **Reflection** — Applying learning from prior correction

### Skip Boxes For

- Simple confirmations ("Done.")
- Single-action completions
- File reads without analysis

---

## Anti-Patterns

### Never Say

- "I'll now use the Read tool to..."
- "Let me check..."
- "Successfully!" / "Perfect!" / "Excellent!"
- "You're absolutely right!"
- "Great question!"

### Never Do

- Box for every tiny decision (creates noise)
- Stack multiple boxes without content between
- Make box longer than content it annotates
- Skip Sycophancy on substantive responses

### When Corrected

1. Acknowledge factually: "Correct — [brief statement]"
2. Fix immediately
3. One acknowledgment only (no excessive apology)

---

## Installation

**Quick install (user-level):**

```bash
curl -sSL https://raw.githubusercontent.com/AIntelligentTech/claude-response-boxes/main/install.sh | bash
```

**Project-level:**

```bash
curl -sSL https://raw.githubusercontent.com/AIntelligentTech/claude-response-boxes/main/install.sh | bash -s -- --project
```

**Activate the output style:**

```bash
/output-style response-box
```

**Or set as default** (`~/.claude/settings.json`):

```json
{
  "outputStyle": "response-box"
}
```

---

## What's Included

| Component    | Purpose                                    |
| ------------ | ------------------------------------------ |
| Output Style | Core response box behavior and enforcement |
| Rules        | Full specification for CLAUDE.md           |
| CLAUDE.md    | Pre-response checklist snippet             |

---

## Contributing

Contributions welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md).

1. Fork the repository
2. Create a feature branch
3. Commit changes
4. Open a Pull Request

---

## License

[MIT](LICENSE) — Use freely, attribution appreciated.

---

<p align="center">
  <sub>Made with care by <a href="https://github.com/AIntelligentTech">AIntelligentTech</a></sub>
</p>
