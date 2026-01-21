#!/usr/bin/env bash
#
# inject-context.sh - SessionStart hook for context injection
#
# Loads high-value boxes from the index and injects them as context
# for the new session. Prioritizes boxes from the same repository.
#
# EXIT CODES:
#   0 - Always (context injection is optional)
#
# OUTPUT:
#   Printed to stdout becomes context for Claude (via additionalContext)
#
# ENVIRONMENT:
#   BOX_INJECT_COUNT    - Number of boxes to inject (default: 5)
#   BOX_INJECT_DISABLED - Set to "true" to disable injection
#

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

INDEX_FILE="${HOME}/.claude/analytics/box-index.json"
INJECT_COUNT="${BOX_INJECT_COUNT:-5}"
MIN_SCORE=70

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main() {
    # Check if disabled
    if [[ "${BOX_INJECT_DISABLED:-false}" == "true" ]]; then
        exit 0
    fi

    # Check if index exists
    if [[ ! -f "$INDEX_FILE" ]]; then
        exit 0
    fi

    # Get current repository
    local current_repo=""
    if git rev-parse --git-dir &>/dev/null; then
        current_repo=$(git remote get-url origin 2>/dev/null | sed -E 's|^(https?://\|git@)||; s|:|/|; s|\.git$||' || echo "")
    fi

    # Query relevant boxes
    local relevant_boxes
    relevant_boxes=$(jq -r --arg repo "$current_repo" --argjson count "$INJECT_COUNT" --argjson min "$MIN_SCORE" '
        .boxes
        | map(select(.score >= $min))
        | map(. + {
            relevance: (
                (if .context.git_remote == $repo and $repo != "" then 1.5 else 1.0 end) * .score
            )
        })
        | sort_by(-.relevance)
        | .[0:$count]
    ' "$INDEX_FILE" 2>/dev/null)

    # Check if we have boxes to inject
    local box_count
    box_count=$(echo "$relevant_boxes" | jq 'length' 2>/dev/null || echo "0")

    if [[ "$box_count" -eq 0 ]] || [[ "$box_count" == "null" ]]; then
        exit 0
    fi

    # Format boxes for injection
    local formatted
    formatted=$(echo "$relevant_boxes" | jq -r '
        map(
            "• \(.type): " +
            (if .type == "Assumption" then
                "Previously assumed \(.fields.what // "N/A")" +
                (if .fields.corrected then " (CORRECTED)" else "" end)
            elif .type == "Choice" then
                "Previously chose \(.fields.selected // "N/A") over \(.fields.alternatives // "N/A")"
            elif .type == "Reflection" then
                "Learning: \(.fields.learning // .fields.application // "N/A")"
            elif .type == "Completion" and .fields.could_improve then
                "Noted improvement: \(.fields.could_improve)"
            elif .type == "Sycophancy" and (.fields.rating | tonumber? // 10) < 7 then
                "Low sycophancy score (\(.fields.rating)) - be more direct"
            else
                (.fields | to_entries | map("\(.key): \(.value)") | .[0:2] | join(", "))
            end)
        ) | join("\n")
    ')

    # Output context if we have content
    if [[ -n "$formatted" ]] && [[ "$formatted" != "null" ]]; then
        echo "PRIOR SESSION LEARNINGS (high-value boxes from previous sessions):"
        echo "$formatted"
        echo ""
        echo "Consider these when processing the current request."
    fi

    exit 0
}

main "$@"
