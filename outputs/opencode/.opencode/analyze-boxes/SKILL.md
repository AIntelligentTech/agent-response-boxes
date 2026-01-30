---
description: AI-powered analysis of response boxes to create learnings and link evidence
---
<!-- Converted from claude to OpenCode -->

# /analyze-boxes Skill

AI-powered analysis of response boxes to identify patterns, create learnings,
and link evidence.

## Trigger

User runs `/analyze-boxes`

---

## Instructions

You are analyzing response boxes from Claude Code sessions to identify patterns
and create learnings. The boxes are stored in `~/.response-boxes/analytics/boxes.jsonl`
as an event-sourced log.

### Step 1: Load and Understand the Data

First, load the event store and find unprocessed boxes:

```bash
# Get last AnalysisCompleted timestamp (epoch)
LAST_ANALYSIS_EPOCH=$(jq -s -r '
  def ts_epoch($v): ($v // "1970-01-01T00:00:00Z") | sub("\\.[0-9]+"; "") | fromdateiso8601;
  ([.[] | select(.event == "AnalysisCompleted")] | sort_by(.ts)) as $runs |
  if ($runs | length) > 0 then ts_epoch($runs[-1].through_ts // $runs[-1].ts)
  else ts_epoch("1970-01-01T00:00:00Z") end
' ~/.response-boxes/analytics/boxes.jsonl 2>/dev/null || echo '0')

# Count boxes since last analysis (legacy lines without .event are treated as BoxCreated)
jq -s --argjson since "$LAST_ANALYSIS_EPOCH" '
  def ts_epoch($v): ($v // "1970-01-01T00:00:00Z") | sub("\\.[0-9]+"; "") | fromdateiso8601;
  [.[] | select(((.event // "BoxCreated") == "BoxCreated") and (ts_epoch(.ts) > $since))] | length
' ~/.response-boxes/analytics/boxes.jsonl
```

Read the full event store to understand:

- Recent BoxCreated events (unprocessed)
- Existing LearningCreated events (what patterns are already known)
- EvidenceLinked events (what boxes support which learnings)

### Step 2: Analyze for Patterns

Look for these pattern types in the unprocessed boxes:

1. **Repeated Choices** — Same library/tool/approach chosen multiple times
2. **Consistent Assumptions** — Similar assumptions made across sessions
3. **Recurring Warnings** — Same risks flagged repeatedly
4. **Pushback Themes** — Patterns in what user directions you disagree with
5. **Completion Gaps** — Frequently noted gaps in task completions
6. **Cross-Session Learning** — Reflection boxes showing applied learnings

### Step 3: Present Findings

For each pattern found, present:

```text
## Pattern: [Brief Description]

**Insight:** [One-sentence learning statement]

**Evidence:**
- Box sess_xxx_1: [summary] (strength: 0.9, supports)
- Box sess_yyy_2: [summary] (strength: 0.7, supports)
- Box sess_zzz_3: [summary] (strength: 0.4, tangential)

**Confidence:** [0.0-1.0 based on evidence strength and quantity]

**Scope:** [global | repo]

**Tags:** [category tags]

**Level:** [0 for direct patterns, 1+ for meta-learnings]
```

### Step 4: Check for Meta-Learnings

Look for opportunities to synthesize existing learnings:

- Multiple level-0 learnings that share a theme
- Patterns across different repositories suggesting global preferences
- Evolution of learnings over time

### Step 5: User Approval

After presenting findings, ask the user to approve which learnings to create.
Format the request clearly:

```text
## Proposed Events

I found the following patterns. Approve to add them to the event store:

1. [x] Learning: "User prefers Zod for validation"
   - Link 3 boxes as evidence
   - Confidence: 0.85, Scope: global

2. [x] Learning: "This repo uses functional patterns"
   - Link 2 boxes as evidence
   - Confidence: 0.78, Scope: repo

3. [ ] Update existing learning_001 confidence to 0.92
   - 2 new supporting boxes found

Which should I add? (all / numbers / none)
```

### Step 6: Emit Events

For approved items, generate and append events:

```bash
# Example: Emit LearningCreated
cat >> ~/.response-boxes/analytics/boxes.jsonl << 'EOF'
{"event":"LearningCreated","id":"learning_XXX","ts":"2026-01-22T15:00:00Z","insight":"User prefers Zod for validation","confidence":0.85,"scope":"global","tags":["validation","typescript"],"level":0}
EOF

# Example: Emit EvidenceLinked
cat >> ~/.response-boxes/analytics/boxes.jsonl << 'EOF'
{"event":"EvidenceLinked","id":"link_XXX","ts":"2026-01-22T15:00:00Z","learning_id":"learning_001","box_id":"sess_abc123_5","strength":0.9,"relationship":"supports"}
EOF

# Example: Emit LearningUpdated
cat >> ~/.response-boxes/analytics/boxes.jsonl << 'EOF'
{"event":"LearningUpdated","id":"lupdate_XXX","ts":"2026-01-22T15:00:00Z","learning_id":"learning_001","updates":{"confidence":0.92}}
EOF

# Example: Emit AnalysisCompleted
cat >> ~/.response-boxes/analytics/boxes.jsonl << 'EOF'
{"event":"AnalysisCompleted","id":"analysis_XXX","ts":"2026-01-22T15:00:00Z","through_ts":"2026-01-22T14:30:00Z","stats":{"boxes_analyzed":47,"learnings_created":3,"learnings_updated":2,"links_created":12}}
EOF
```

### ID Generation

Use these patterns for IDs:

- `learning_NNN` — Sequential learning number
- `link_NNN` — Sequential link number
- `llink_NNN` — Sequential learning link number
- `lupdate_NNN` — Sequential learning update number
- `analysis_NNN` — Sequential analysis number

Find the next number:

```bash
jq -s '[.[] | select(.id | startswith("learning_"))] | length + 1' ~/.response-boxes/analytics/boxes.jsonl
```

---

## Event Schemas

### LearningCreated

```json
{
  "event": "LearningCreated",
  "id": "learning_001",
  "ts": "2026-01-22T15:00:00Z",
  "insight": "User prefers Zod for validation",
  "confidence": 0.85,
  "scope": "global",
  "tags": ["validation", "typescript"],
  "level": 0
}
```

### EvidenceLinked

```json
{
  "event": "EvidenceLinked",
  "id": "link_001",
  "ts": "2026-01-22T15:00:00Z",
  "learning_id": "learning_001",
  "box_id": "sess_abc123_5",
  "strength": 0.9,
  "relationship": "supports"
}
```

Relationship types:

- `supports` — Positive evidence
- `contradicts` — Counter-evidence
- `tangential` — Related but not direct

### LearningLinked

For meta-learnings that synthesize others:

```json
{
  "event": "LearningLinked",
  "id": "llink_001",
  "ts": "2026-01-22T16:00:00Z",
  "parent_learning_id": "learning_010",
  "child_learning_id": "learning_001",
  "relationship": "synthesizes"
}
```

Relationship types:

- `synthesizes` — Parent combines children
- `refines` — Parent is more specific
- `supersedes` — Parent replaces child

### LearningUpdated

```json
{
  "event": "LearningUpdated",
  "id": "lupdate_001",
  "ts": "2026-01-22T16:00:00Z",
  "learning_id": "learning_001",
  "updates": {
    "confidence": 0.92
  }
}
```

### AnalysisCompleted

```json
{
  "event": "AnalysisCompleted",
  "id": "analysis_001",
  "ts": "2026-01-22T15:00:00Z",
  "through_ts": "2026-01-22T14:30:00Z",
  "stats": {
    "boxes_analyzed": 47,
    "learnings_created": 3,
    "learnings_updated": 2,
    "links_created": 12
  }
}
```

---

## Guidelines

### Confidence Scoring

| Evidence                   | Confidence |
| -------------------------- | ---------- |
| 5+ strong supporting boxes | 0.9+       |
| 3-4 supporting boxes       | 0.75-0.85  |
| 2 supporting boxes         | 0.6-0.7    |
