# Response Box System

**ALWAYS ACTIVE** — Apply these boxes to every substantive response.

**Version:** 1.1.0

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        RESPONSE BOX META-COGNITION SYSTEM                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │   GENERATE  │───▶│   COLLECT   │───▶│    STORE    │───▶│   ANALYZE   │  │
│  │             │    │             │    │             │    │             │  │
│  │ Claude adds │    │ Hook parses │    │   JSONL     │    │  Patterns   │  │
│  │ boxes to    │    │ boxes from  │    │  appended   │    │  extracted  │  │
│  │ response    │    │ response    │    │             │    │             │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│         │                                                        │          │
│         │                    ┌─────────────┐                     │          │
│         │                    │   REFLECT   │                     │          │
│         └───────────────────▶│             │◀────────────────────┘          │
│                              │ Claude      │                                │
│                              │ reviews     │                                │
│                              │ prior boxes │                                │
│                              └─────────────┘                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Single-Turn Execution Flow

```
User Request
     │
     ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                           CLAUDE PROCESSING                                 │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  1. REVIEW (turn start)          2. EXECUTE                  3. ANNOTATE  │
│  ┌────────────────────┐          ┌─────────────────┐        ┌──────────┐  │
│  │ Check prior boxes: │          │ Perform task:   │        │ Add end  │  │
│  │ • Was assumption   │─────────▶│ • Code changes  │───────▶│ boxes:   │  │
│  │   corrected?       │          │ • Research      │        │ • 📋     │  │
│  │ • Did user pick    │          │ • Analysis      │        │ • 🏁     │  │
│  │   different choice?│          │                 │        │ • 🪞     │  │
│  │ • Any gaps noted?  │          │ [Inline boxes   │        │          │  │
│  └────────────────────┘          │  as relevant]   │        └──────────┘  │
│           │                      │ ⚖️ 🎯 💭 📊 ↩️    │              │       │
│           │                      └─────────────────┘              │       │
│           │                             │                         │       │
│           ▼                             ▼                         ▼       │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                         RESPONSE OUTPUT                              │  │
│  │  [Optional: 🔄 Reflection if learning applied]                       │  │
│  │  [Content with inline boxes]                                         │  │
│  │  [End boxes: 📋 → 🏁 → 🪞]                                            │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
     │
     ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                         POST-RESPONSE HOOK                                  │
├────────────────────────────────────────────────────────────────────────────┤
│  collect-boxes.sh:                                                         │
│  1. Parse response for emoji patterns (⚖️|🎯|💭|...)                        │
│  2. Extract fields (**Field:** Value)                                      │
│  3. Gather context (git remote, branch, session)                           │
│  4. Append JSON record to boxes.jsonl                                      │
└────────────────────────────────────────────────────────────────────────────┘
```

### Multi-Turn Meta-Cognition Loop

```
Turn N                              Turn N+1                          Turn N+2
┌─────────┐                        ┌─────────┐                        ┌─────────┐
│ Request │                        │ Request │                        │ Request │
└────┬────┘                        └────┬────┘                        └────┬────┘
     │                                  │                                  │
     ▼                                  ▼                                  ▼
┌─────────┐                        ┌─────────┐                        ┌─────────┐
│Response │                        │Response │                        │Response │
│with     │                        │with     │                        │with     │
│boxes:   │                        │boxes:   │                        │boxes:   │
│         │                        │         │                        │         │
│💭 Assume│───────────────────────▶│🔄 Prior │                        │         │
│  "X"    │  Claude remembers      │  assumption                      │         │
│         │  the assumption        │  corrected!│                     │         │
│🏁 Could │                        │         │───────────────────────▶│ Applied │
│  improve│───────────────────────▶│ Apply   │  Learning persists     │ learning│
│  by Y   │  Claude remembers      │ learning│                        │         │
│         │  self-critique         │ Y       │                        │         │
└─────────┘                        └─────────┘                        └─────────┘
     │                                  │                                  │
     ▼                                  ▼                                  ▼
[boxes.jsonl]                      [boxes.jsonl]                      [boxes.jsonl]
```

**Current Limitation:** The reflection loop relies on Claude's conversational
memory. In long sessions or across sessions, prior boxes may not be available
for review. The JSONL storage enables future tooling to inject prior boxes.

---

## Quick Reference

| Emoji | Type       | When                                 | Placement |
| ----- | ---------- | ------------------------------------ | --------- |
| ⚖️    | Choice     | Selected between alternatives        | Inline    |
| 🎯    | Decision   | Made judgment call                   | Inline    |
| 💭    | Assumption | Filled unstated requirement          | Inline    |
| 📊    | Confidence | Claim with uncertainty (<90%)        | Inline    |
| ↩️    | Pushback   | Disagree with user direction         | Inline    |
| ⚠️    | Concern    | Potential risk to flag               | Inline    |
| 💡    | Suggestion | Optional improvement                 | Inline    |
| 🚨    | Warning    | Serious risk                         | Inline    |
| ★     | Insight    | Educational point (explanatory mode) | Inline    |
| 🔄    | Reflection | Applied learning from prior box      | Start     |
| 🪞    | Sycophancy | Anti-sycophancy check                | End       |
| ✅    | Quality    | Code quality assessment              | End       |
| 📋    | Follow Ups | Next steps for user                  | End       |
| 🏁    | Completion | Task completion assessment           | End       |

---

## Box Format Standard

```
[emoji] [Type] ─────────────────────────────────
**[Field1]:** [Value]
**[Field2]:** [Value]
────────────────────────────────────────────────
```

- 45 dashes (fits 80-char terminals)
- Fields vary by box type (see specifications below)
- Keep content concise — box should not exceed content it annotates

---

## Placement Rules

### Inline Boxes (Place immediately at point of relevance)

**REQUIRED when applicable:**

- ⚖️ Choice — ALWAYS when selecting between 2+ alternatives
- 🎯 Decision — ALWAYS when making judgment calls
- 💭 Assumption — ALWAYS when filling unstated requirements
- ⚠️ Concern — When flagging potential issues

**Use when needed:**

- 📊 Confidence — For claims with meaningful uncertainty
- ↩️ Pushback — When genuinely disagreeing
- 💡 Suggestion — For optional improvements
- 🚨 Warning — For serious risks (higher than Concern)
- ★ Insight — Explanatory mode only

### End-of-Response Boxes (Max 3, in this order)

```
[Response content...]

📋 Follow Ups (if next steps exist)
🏁 Completion (if task being completed)
✅ Quality (if code was written)
🪞 Sycophancy (ALWAYS for substantive responses)
```

**Rule:** Max 3 end boxes. 🪞 Sycophancy always last. Choose 2 most relevant
others.

---

## Box Specifications

### Inline Boxes

#### ⚖️ Choice

**When:** Selected between 2+ viable alternatives **Fields:** Selected,
Alternatives, Reasoning

```
⚖️ Choice ───────────────────────────────────────
**Selected:** [What was chosen]
**Alternatives:** [What was not chosen]
**Reasoning:** [Why this choice]
────────────────────────────────────────────────
```

#### 🎯 Decision

**When:** Made a judgment call without clear alternatives **Fields:** What,
Reasoning

```
🎯 Decision ─────────────────────────────────────
**What:** [The decision made]
**Reasoning:** [Justification]
────────────────────────────────────────────────
```

#### 💭 Assumption

**When:** Filled in unstated requirements or context **Fields:** What, Basis

```
💭 Assumption ───────────────────────────────────
**What:** [What was assumed]
**Basis:** [Why this assumption is reasonable]
────────────────────────────────────────────────
```

#### 📊 Confidence

**When:** Making technical claim with meaningful uncertainty (<90%) **Fields:**
Claim, Level (1-10), Basis

```
📊 Confidence ───────────────────────────────────
**Claim:** [The statement]
**Level:** X/10
**Basis:** [Evidence or lack thereof]
────────────────────────────────────────────────
```

#### ↩️ Pushback

**When:** Disagreeing with user's direction or request **Fields:** Position,
Reasoning

```
↩️ Pushback ─────────────────────────────────────
**Position:** [What I disagree with]
**Reasoning:** [Why, with evidence]
────────────────────────────────────────────────
```

#### ⚠️ Concern

**When:** Flagging potential issue user should know **Fields:** Issue, Impact,
Mitigation (optional)

```
⚠️ Concern ──────────────────────────────────────
**Issue:** [The concern]
**Impact:** [What could go wrong]
**Mitigation:** [How to address, if known]
────────────────────────────────────────────────
```

#### 💡 Suggestion

**When:** Offering optional improvement not directly requested **Fields:** Idea,
Benefit

```
💡 Suggestion ───────────────────────────────────
**Idea:** [The suggestion]
**Benefit:** [Why it's valuable]
────────────────────────────────────────────────
```

#### 🚨 Warning

**When:** Serious risk that could cause significant harm **Fields:** Risk,
Likelihood, Consequence

```
🚨 Warning ──────────────────────────────────────
**Risk:** [What could go wrong]
**Likelihood:** [How likely]
**Consequence:** [Impact if it happens]
────────────────────────────────────────────────
```

#### ★ Insight

**When:** Explanatory mode only — educational point **Fields:** Key point
(free-form)

```
`★ Insight ─────────────────────────────────────`
[Educational content — 2-3 key points]
`─────────────────────────────────────────────────`
```

Note: Uses backticks per existing convention.

#### 🔄 Reflection

**When:** Applying a learning from a prior box (assumption corrected, choice
validated, gap addressed) **Fields:** Prior, Learning, Application

```
🔄 Reflection ───────────────────────────────────
**Prior:** [What was noted in previous box]
**Learning:** [What was learned from outcome]
**Application:** [How it affects current response]
────────────────────────────────────────────────
```

**Placement:** Start of response (after greeting if any, before main content).
Only use when the learning materially affects the current response.

---

### End-of-Response Boxes

#### 📋 Follow Ups

**When:** Task complete and there are clear next steps **Fields:** Immediate,
Consider, Related

```
📋 Follow Ups ───────────────────────────────────
**Immediate:** [Actions user should take now]
**Consider:** [Optional improvements]
**Related:** [Connected topics to explore]
────────────────────────────────────────────────
```

#### 🏁 Completion

**When:** Completing a task — FORCES reassessment of original request
**Fields:** Request, Completed, Confidence, Gaps, Could Improve

```
🏁 Completion ───────────────────────────────────
**Request:** [Brief restatement of what was asked]
**Completed:** [List what was done]
**Confidence:** X/10
**Gaps:** [Any aspects not fully addressed]
**Could Improve:** [Self-critique of process/output]
────────────────────────────────────────────────
```

#### ✅ Quality

**When:** After writing significant code **Fields:** Rating, Justification

```
✅ Quality ──────────────────────────────────────
**Rating:** X/10
**Justification:** [Brief assessment]
────────────────────────────────────────────────
```

#### 🪞 Sycophancy

**When:** ALWAYS for substantive responses **Fields:** Rating, Check

```
🪞 Sycophancy ───────────────────────────────────
**Rating:** X/10 (10 = no sycophancy)
**Check:** [Brief reasoning]
────────────────────────────────────────────────
```

---

## Policy: When to Use Each

### ALWAYS USE (every substantive response)

- 🪞 Sycophancy — End of response

### ALWAYS USE WHEN COMPLETING TASKS

- 🏁 Completion — End of response, forces task reassessment

### ALWAYS USE WHEN APPLICABLE (inline)

- ⚖️ Choice — When selecting between alternatives
- 🎯 Decision — When making judgment calls
- 💭 Assumption — When filling unstated requirements
- ⚠️ Concern — When flagging potential issues

### USE WHEN NEEDED (inline)

- 📊 Confidence — Claims with uncertainty
- ↩️ Pushback — Disagreeing with direction
- 💡 Suggestion — Optional improvements
- 🚨 Warning — Serious risks
- ★ Insight — Explanatory mode only

### USE AFTER CODE DELIVERY (end)

- ✅ Quality — Code quality assessment

### USE WHEN NEXT STEPS EXIST (end)

- 📋 Follow Ups — Clear next actions

---

## Distinction Guide

| Situation                                       | Use           |
| ----------------------------------------------- | ------------- |
| "Should I use library A or B?" → selected A     | ⚖️ Choice     |
| "I'll use approach X" (no alternatives weighed) | 🎯 Decision   |
| User didn't specify, I filled in                | 💭 Assumption |
| "This might cause issues"                       | ⚠️ Concern    |
| "This WILL cause serious problems"              | 🚨 Warning    |
| "I think user is wrong"                         | ↩️ Pushback   |
| "You could also do X"                           | 💡 Suggestion |
| "I'm 70% sure this is correct"                  | 📊 Confidence |
| Teaching moment in explanatory mode             | ★ Insight     |

---

## Anti-Patterns (Don't Do This)

- ❌ Box for every tiny decision (noise)
- ❌ Multiple boxes stacked inline without content between
- ❌ Box longer than the content it annotates
- ❌ Insight boxes for obvious things
- ❌ Confidence boxes when certainty is 100%
- ❌ More than 3 end-of-response boxes
- ❌ Skipping 🪞 Sycophancy on substantive responses
- ❌ Skipping 🏁 Completion on task completions

---

## Verbosity Preference

**PREFER MORE BOXES OVER FEWER** — Important information should not be missed.

If in doubt about whether to include a box, include it. The cost of missing
important context is higher than minor verbosity.

---

## Self-Reflection on Previous Boxes

### How Self-Reflection Works

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SELF-REFLECTION MECHANISM                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  DATA SOURCE: Conversational Memory (within current session)               │
│                                                                             │
│  ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐   │
│  │   Your Prior     │     │   User's Next    │     │  Check: Did user │   │
│  │   Response       │────▶│   Message        │────▶│  correct/validate│   │
│  │   (with boxes)   │     │                  │     │  /redirect?      │   │
│  └──────────────────┘     └──────────────────┘     └────────┬─────────┘   │
│                                                              │              │
│                           ┌──────────────────────────────────┼──────────┐  │
│                           │                                  ▼          │  │
│                           │  YES: User corrected    NO: Proceed normally│  │
│                           │       assumption or            │            │  │
│                           │       chose differently        │            │  │
│                           │              │                 │            │  │
│                           │              ▼                 │            │  │
│                           │  ┌─────────────────────┐       │            │  │
│                           │  │ 🔄 Reflection Box   │       │            │  │
│                           │  │ at response start   │       │            │  │
│                           │  └─────────────────────┘       │            │  │
│                           └─────────────────────────────────────────────┘  │
│                                                                             │
│  LIMITATION: Only works within active session. Cross-session reflection    │
│  requires external tooling (future: prior-box injection).                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**At the start of each turn**, briefly review boxes from your previous response
using your conversational memory:

### What to Review

| Prior Box     | Check For                         | Action                               |
| ------------- | --------------------------------- | ------------------------------------ |
| 🏁 Completion | "Gaps" or "Could Improve" filled? | Address if still relevant            |
| 💭 Assumption | User corrected or confirmed?      | Update approach, use 🔄 Reflection   |
| ⚖️ Choice     | User preferred alternative?       | Note preference, use 🔄 Reflection   |
| 📊 Confidence | Claim was wrong?                  | Correct, increase epistemic humility |
| 🪞 Sycophancy | Rating was low?                   | Be more direct this turn             |

### When to Use 🔄 Reflection Box

**USE when:**

- User explicitly corrected an assumption → Show you learned
- User chose differently than you selected → Acknowledge preference
- Completion "Could Improve" directly applies → Show proactive improvement
- Pattern emerges across multiple corrections → Synthesize the learning

**DON'T USE when:**

- Learning is minor (repo name, formatting preference)
- User has moved on to unrelated topic
- Reflection would delay urgent task
- Same learning already reflected in prior turn

### Integration Pattern

```
[Start of response]

🔄 Reflection ───────────────────────────────────
**Prior:** In my last response, I assumed TypeScript
**Learning:** You prefer JavaScript for this project
**Application:** Using JavaScript for all examples below
────────────────────────────────────────────────

[Continue with current task using learned preference...]

[End boxes as normal]
```

### Cross-Session Continuity

Within a session, use conversational memory. For cross-session learnings:

1. **Persistent rules** — Extract to CLAUDE.md if pattern repeats 3+ times
2. **Analytics review** — Run `analyze-boxes.sh` to spot patterns
3. **Future tooling** — Prior-box injection will enable automatic context

---

## Recording & Analysis System

### JSONL Record Schema

Each box is stored as a single JSON line in `~/.claude/analytics/boxes.jsonl`.

**Key design principle:** Use git-based identifiers, not filesystem paths. This
ensures:

- Same repo on different machines → same identifier
- Portable analytics across environments
- No leakage of local filesystem structure

```json
{
  "ts": "2026-01-21T18:30:00Z",
  "type": "Choice",
  "fields": {
    "selected": "Haiku model",
    "alternatives": "Sonnet, Opus",
    "reasoning": "Cost-effective for analysis-only task"
  },
  "context": {
    "session_id": "abc123def456",
    "git_remote": "github.com/user/repo",
    "git_branch": "main",
    "relative_path": "src/components/Button.tsx",
    "model": "claude-opus-4",
    "turn_number": 12
  }
}
```

### Context Fields

| Field           | Source                            | Purpose                                 |
| --------------- | --------------------------------- | --------------------------------------- |
| `session_id`    | `$CLAUDE_SESSION_ID` or generated | Correlate boxes within session          |
| `git_remote`    | `git remote get-url origin`       | Primary project identifier (portable)   |
| `git_branch`    | `git branch --show-current`       | Track patterns by branch                |
| `relative_path` | Path from git root                | File context without absolute paths     |
| `model`         | Claude Code internals             | Track behavior by model                 |
| `turn_number`   | Conversation position             | Identify early vs late session patterns |

### Why Git-Based Identifiers?

**Problem with filesystem paths:**

- `/Users/alice/projects/my-app` ≠ `/home/bob/my-app` (same repo!)
- Leaks username and directory structure
- Breaks when repo moves or is cloned elsewhere

**Solution with git remote:**

- `github.com/org/my-app` is globally unique
- Same across all clones
- Identifies repo without exposing local structure

**For non-git directories:**

- Fall back to directory basename (e.g., `my-app`)
- Optionally use `$PROJECT_ID` env var if set

### Proposed Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    BOX TRACKING SYSTEM                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  COLLECTION (PostToolUse hook):                                 │
│  ├─ ~/.claude/hooks/collect-boxes.sh                            │
│  ├─ Parse response for emoji box patterns                       │
│  ├─ Extract: type, fields, git-based context                    │
│  └─ Append to: ~/.claude/analytics/boxes.jsonl                  │
│                                                                  │
│  CONTEXT GATHERING:                                             │
│  ├─ session_id: $CLAUDE_SESSION_ID or UUID                      │
│  ├─ git_remote: git remote get-url origin | sed 's|.*://||'     │
│  ├─ git_branch: git branch --show-current                       │
│  ├─ relative_path: git-root-relative path of last edited file   │
│  └─ model/turn: from Claude Code environment                    │
│                                                                  │
│  ANALYSIS:                                                       │
│  ├─ ~/.claude/scripts/analyze-boxes.sh                          │
│  ├─ Box frequency by type and repo                              │
│  ├─ Confidence distribution over time                           │
│  ├─ Common assumptions (grouped by similarity)                  │
│  └─ Completion confidence trends                                │
│                                                                  │
│  RETENTION:                                                      │
│  ├─ Raw: 90 days in boxes.jsonl                                 │
│  ├─ Aggregates: indefinite in boxes-summary.json                │
│  └─ Rotation: monthly archive to boxes-YYYY-MM.jsonl.gz         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Example Queries

```bash
# Boxes from last 24 hours
jq -s '[.[] | select(.ts > "2026-01-20")]' ~/.claude/analytics/boxes.jsonl

# All assumptions in a specific repo
jq -s '[.[] | select(.type=="Assumption" and .context.git_remote=="github.com/org/repo")]' ~/.claude/analytics/boxes.jsonl

# Average confidence level
jq -s '[.[] | select(.type=="Confidence") | .fields.level] | add / length' ~/.claude/analytics/boxes.jsonl

# Boxes per repository
jq -s 'group_by(.context.git_remote) | map({repo: .[0].context.git_remote, count: length})' ~/.claude/analytics/boxes.jsonl

# Pushback frequency (am I challenging enough?)
jq -s '[.[] | select(.type=="Pushback")] | length' ~/.claude/analytics/boxes.jsonl
```

---

## Changelog

- **v1.1.0** (2026-01-21): Meta-cognition loop refinements
  - Added System Architecture diagram
  - Added Single-Turn Execution Flow diagram
  - Added Multi-Turn Meta-Cognition Loop diagram
  - Added 🔄 Reflection box for applying learnings from prior boxes
  - Enhanced Self-Reflection section with mechanism diagram and decision tables
  - Documented cross-session continuity guidance
- **v1.0.0** (2026-01-21): Initial release
