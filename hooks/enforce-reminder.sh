#!/usr/bin/env bash
#
# enforce-reminder.sh - PostToolUse hook for context injection
#
# Injects a reminder about response boxes into Claude's context after tool use.
# This uses the additionalContext feature (Claude Code v2.1.9+).
#
# EXIT CODES:
#   0 - Always (never blocks tool execution)
#
# OUTPUT:
#   Printed to stdout becomes additionalContext for Claude
#

# Only inject reminder occasionally (every 3rd tool call) to avoid noise
# Track via a simple counter file
COUNTER_FILE="/tmp/.claude-box-reminder-counter"

count=0
if [[ -f "$COUNTER_FILE" ]]; then
    count=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
fi

count=$((count + 1))
echo "$count" > "$COUNTER_FILE"

# Inject reminder every 3rd call
if [[ $((count % 3)) -eq 0 ]]; then
    echo "REMINDER: For substantive responses, include response boxes (⚖️ Choice, 🎯 Decision, 💭 Assumption) and explain reasoning (WHY, not just WHAT). End with 🪞 Sycophancy box."
fi

exit 0
