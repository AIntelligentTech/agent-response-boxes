---
name: response-boxes-start
description:
  Initialize Response Boxes context for this session by loading prior learnings
  and notable boxes
---

# /response-boxes-start

This workflow projects learnings and notable boxes from prior sessions to
provide cross-session context for Cascade.

## Purpose

Because Windsurf hooks cannot inject context automatically at session start,
this workflow provides a manual mechanism to load cross-session learnings. Run
this command at the beginning of a session to see relevant patterns and boxes
from your previous work.

## Usage

Type `/response-boxes-start` in Cascade to execute this workflow.

## What It Does

1. **Read the event store** at `~/.response-boxes/analytics/boxes.jsonl`
2. **Project top learnings** sorted by confidence and recency
3. **Project notable boxes** from recent sessions
4. **Display context block** for you to reference

## Context Block Format

After running this workflow, you'll see output like:

```
PRIOR SESSION LEARNINGS (from Response Boxes):

Patterns (AI-synthesized learnings)
• [0.92] User prefers Zod for validation over Yup
• [0.85] This project uses functional patterns consistently
• [0.78] Always check for rate limiting on public endpoints

Recent notable boxes
• Warning: No authentication on DELETE endpoint [github.com/user/api]
• Assumption: Using TypeScript based on tsconfig.json [github.com/user/repo]
• Choice: Selected PostgreSQL over SQLite for production [github.com/user/app]
```

## Configuration

Environment variables (set in your shell profile):

| Variable               | Default                                   | Description              |
| ---------------------- | ----------------------------------------- | ------------------------ |
| `BOX_INJECT_LEARNINGS` | 3                                         | Max learnings to display |
| `BOX_INJECT_BOXES`     | 5                                         | Max boxes to display     |
| `RESPONSE_BOXES_FILE`  | `~/.response-boxes/analytics/boxes.jsonl` | Event store location     |

## Manual Projection Script

If you prefer to run this outside of a workflow, use:

```bash
~/.response-boxes/hooks/project-context.sh
```

Or read the event store directly:

```bash
cat ~/.response-boxes/analytics/boxes.jsonl | \
  jq -s 'map(select(.event == "LearningCreated")) | sort_by(-.confidence) | .[0:3]'
```

## Integration with Response Boxes

This workflow is part of the Response Boxes cross-session learning system:

1. **Collection**: Boxes are automatically captured via `post_cascade_response`
   hook
2. **Storage**: Events are appended to `~/.response-boxes/analytics/boxes.jsonl`
3. **Analysis**: Run `/analyze-boxes` (in Claude Code) to synthesize learnings
4. **Injection**: Use this workflow to load context at session start

## Troubleshooting

**No output?**

- Check that `~/.response-boxes/analytics/boxes.jsonl` exists
- Ensure you have completed sessions with Response Boxes enabled
- Run `/analyze-boxes` in Claude Code to create learnings

**Outdated learnings?**

- Run `/analyze-boxes` to process recent boxes into learnings
- Learnings use recency decay; older ones may have lower confidence

**Want different limits?**

- Set `BOX_INJECT_LEARNINGS` and `BOX_INJECT_BOXES` environment variables

## See Also

- Response Boxes rules: `.windsurf/rules/response-boxes.md`
- Architecture documentation: `docs/architecture.md`
- Cross-agent compatibility: `docs/cross-agent-compatibility.md`
