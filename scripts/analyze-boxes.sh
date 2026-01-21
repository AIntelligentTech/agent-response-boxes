#!/usr/bin/env bash
#
# analyze-boxes.sh - Analyze response box patterns
#
# Provides insights into Claude's metacognitive patterns from collected boxes.
#
# USAGE:
#   ./analyze-boxes.sh [OPTIONS]
#
# OPTIONS:
#   -h, --help          Show this help
#   -f, --file FILE     Analytics file (default: ~/.claude/analytics/boxes.jsonl)
#   -d, --days N        Analyze last N days only (default: all)
#   -r, --repo REPO     Filter by git remote (e.g., github.com/org/repo)
#   -j, --json          Output as JSON instead of formatted text
#   -s, --summary       Show summary only (no details)
#
# EXAMPLES:
#   ./analyze-boxes.sh                          # Full analysis
#   ./analyze-boxes.sh -d 7                     # Last 7 days
#   ./analyze-boxes.sh -r github.com/org/repo   # Specific repo
#   ./analyze-boxes.sh -j | jq .                # JSON output
#

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

ANALYTICS_FILE="${HOME}/.claude/analytics/boxes.jsonl"
DAYS=""
REPO_FILTER=""
JSON_OUTPUT=false
SUMMARY_ONLY=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─────────────────────────────────────────────────────────────────────────────
# Argument Parsing
# ─────────────────────────────────────────────────────────────────────────────

show_help() {
    grep '^#' "$0" | grep -v '#!/' | sed 's/^# \?//' | head -25
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)    show_help ;;
            -f|--file)    ANALYTICS_FILE="$2"; shift 2 ;;
            -d|--days)    DAYS="$2"; shift 2 ;;
            -r|--repo)    REPO_FILTER="$2"; shift 2 ;;
            -j|--json)    JSON_OUTPUT=true; shift ;;
            -s|--summary) SUMMARY_ONLY=true; shift ;;
            *)            echo "Unknown option: $1"; exit 1 ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# Data Loading
# ─────────────────────────────────────────────────────────────────────────────

load_data() {
    if [[ ! -f "$ANALYTICS_FILE" ]]; then
        echo "No analytics file found at $ANALYTICS_FILE" >&2
        echo "Run some Claude Code sessions with box collection enabled first." >&2
        exit 1
    fi

    local filter="."

    # Apply date filter
    if [[ -n "$DAYS" ]]; then
        local since
        since=$(date -v-${DAYS}d -Iseconds 2>/dev/null || date -d "-${DAYS} days" -Iseconds)
        filter="select(.ts >= \"$since\")"
    fi

    # Apply repo filter
    if [[ -n "$REPO_FILTER" ]]; then
        filter="$filter | select(.context.git_remote == \"$REPO_FILTER\")"
    fi

    # Load and filter data
    jq -s "[ .[] | $filter ]" "$ANALYTICS_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
# Analysis Functions
# ─────────────────────────────────────────────────────────────────────────────

analyze() {
    local data="$1"

    # Calculate metrics
    local total
    total=$(echo "$data" | jq 'length')

    if [[ "$total" -eq 0 ]]; then
        echo "No boxes found matching criteria." >&2
        exit 0
    fi

    # Box counts by type
    local by_type
    by_type=$(echo "$data" | jq '
        group_by(.type) |
        map({type: .[0].type, count: length}) |
        sort_by(-.count)
    ')

    # Unique sessions
    local sessions
    sessions=$(echo "$data" | jq '[.[].context.session_id] | unique | length')

    # Unique repos
    local repos
    repos=$(echo "$data" | jq '[.[].context.git_remote] | unique | length')

    # Confidence stats (if any Confidence boxes)
    local confidence_avg confidence_min confidence_max
    local confidence_data
    confidence_data=$(echo "$data" | jq '[.[] | select(.type == "Confidence") | .fields.level | tonumber? // empty]')
    confidence_avg=$(echo "$confidence_data" | jq 'if length > 0 then add / length | . * 10 | round / 10 else null end')
    confidence_min=$(echo "$confidence_data" | jq 'if length > 0 then min else null end')
    confidence_max=$(echo "$confidence_data" | jq 'if length > 0 then max else null end')

    # Sycophancy stats
    local sycophancy_data
    sycophancy_data=$(echo "$data" | jq '[.[] | select(.type == "Sycophancy") | .fields.rating | tonumber? // empty]')
    local sycophancy_avg
    sycophancy_avg=$(echo "$sycophancy_data" | jq 'if length > 0 then add / length | . * 10 | round / 10 else null end')

    # Top repos by box count
    local top_repos
    top_repos=$(echo "$data" | jq '
        group_by(.context.git_remote) |
        map({repo: .[0].context.git_remote, count: length}) |
        sort_by(-.count) |
        .[0:5]
    ')

    # Recent assumptions (last 10)
    local recent_assumptions
    recent_assumptions=$(echo "$data" | jq '
        [.[] | select(.type == "Assumption")] |
        sort_by(.ts) |
        reverse |
        .[0:10] |
        map({ts: .ts, what: .fields.what, repo: .context.git_remote})
    ')

    # Pushback count (indicator of healthy challenge)
    local pushback_count
    pushback_count=$(echo "$data" | jq '[.[] | select(.type == "Pushback")] | length')

    # Time range
    local first_ts last_ts
    first_ts=$(echo "$data" | jq -r 'sort_by(.ts) | .[0].ts // "N/A"')
    last_ts=$(echo "$data" | jq -r 'sort_by(.ts) | .[-1].ts // "N/A"')

    # Build result
    local result
    result=$(jq -n \
        --argjson total "$total" \
        --argjson sessions "$sessions" \
        --argjson repos "$repos" \
        --argjson by_type "$by_type" \
        --argjson confidence_avg "$confidence_avg" \
        --argjson confidence_min "$confidence_min" \
        --argjson confidence_max "$confidence_max" \
        --argjson sycophancy_avg "$sycophancy_avg" \
        --argjson pushback_count "$pushback_count" \
        --argjson top_repos "$top_repos" \
        --argjson recent_assumptions "$recent_assumptions" \
        --arg first_ts "$first_ts" \
        --arg last_ts "$last_ts" \
        '{
            summary: {
                total_boxes: $total,
                unique_sessions: $sessions,
                unique_repos: $repos,
                time_range: {first: $first_ts, last: $last_ts}
            },
            by_type: $by_type,
            insights: {
                confidence: {
                    avg: $confidence_avg,
                    min: $confidence_min,
                    max: $confidence_max
                },
                sycophancy_avg: $sycophancy_avg,
                pushback_count: $pushback_count
            },
            top_repos: $top_repos,
            recent_assumptions: $recent_assumptions
        }')

    echo "$result"
}

# ─────────────────────────────────────────────────────────────────────────────
# Output Formatting
# ─────────────────────────────────────────────────────────────────────────────

format_output() {
    local result="$1"

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "$result" | jq .
        return
    fi

    # Extract values
    local total sessions repos first_ts last_ts
    total=$(echo "$result" | jq -r '.summary.total_boxes')
    sessions=$(echo "$result" | jq -r '.summary.unique_sessions')
    repos=$(echo "$result" | jq -r '.summary.unique_repos')
    first_ts=$(echo "$result" | jq -r '.summary.time_range.first')
    last_ts=$(echo "$result" | jq -r '.summary.time_range.last')

    local confidence_avg sycophancy_avg pushback_count
    confidence_avg=$(echo "$result" | jq -r '.insights.confidence.avg // "N/A"')
    sycophancy_avg=$(echo "$result" | jq -r '.insights.sycophancy_avg // "N/A"')
    pushback_count=$(echo "$result" | jq -r '.insights.pushback_count')

    echo ""
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}                 RESPONSE BOX ANALYTICS${NC}"
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${DIM}File:${NC}     $ANALYTICS_FILE"
    echo -e "${DIM}Period:${NC}   $first_ts → $last_ts"
    [[ -n "$DAYS" ]] && echo -e "${DIM}Filter:${NC}   Last $DAYS days"
    [[ -n "$REPO_FILTER" ]] && echo -e "${DIM}Repo:${NC}     $REPO_FILTER"
    echo ""

    echo -e "${BOLD}Summary${NC}"
    echo -e "  Total boxes:      ${GREEN}$total${NC}"
    echo -e "  Unique sessions:  $sessions"
    echo -e "  Unique repos:     $repos"
    echo ""

    echo -e "${BOLD}By Type${NC}"
    echo "$result" | jq -r '.by_type[] | "  \(.type): \(.count)"'
    echo ""

    echo -e "${BOLD}Insights${NC}"
    echo -e "  Avg confidence:   ${CYAN}${confidence_avg}${NC}/10"
    echo -e "  Avg sycophancy:   ${CYAN}${sycophancy_avg}${NC}/10 (10 = no sycophancy)"
    echo -e "  Pushback count:   ${YELLOW}${pushback_count}${NC}"

    if [[ "$pushback_count" -eq 0 ]] && [[ "$total" -gt 20 ]]; then
        echo -e "  ${DIM}→ Consider: Are you challenging users enough?${NC}"
    fi
    echo ""

    if [[ "$SUMMARY_ONLY" == "false" ]]; then
        echo -e "${BOLD}Top Repositories${NC}"
        echo "$result" | jq -r '.top_repos[] | "  \(.repo): \(.count) boxes"'
        echo ""

        echo -e "${BOLD}Recent Assumptions${NC}"
        echo "$result" | jq -r '.recent_assumptions[:5][] | "  • \(.what // "N/A") (\(.repo))"'
        echo ""
    fi

    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main() {
    # Check for jq
    if ! command -v jq &>/dev/null; then
        echo "Error: jq is required but not installed" >&2
        exit 1
    fi

    parse_args "$@"

    local data
    data=$(load_data)

    local result
    result=$(analyze "$data")

    format_output "$result"
}

main "$@"
