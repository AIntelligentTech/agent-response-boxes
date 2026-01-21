#!/usr/bin/env bash
#
# session-end-analyze.sh - Session-end analysis, scoring, and indexing
#
# Runs at session end to:
# 1. Extract boxes from this session
# 2. Score each box by importance
# 3. Update the high-value box index
# 4. Optionally run headless Claude for deeper analysis
# 5. Backfill any unscored boxes from previous sessions
#
# USAGE:
#   ./session-end-analyze.sh [OPTIONS]
#
# OPTIONS:
#   -h, --help           Show this help
#   -s, --session ID     Session ID to analyze (default: $CLAUDE_SESSION_ID)
#   -a, --all            Process all unscored boxes (backfill mode)
#   -d, --deep           Run headless Claude for deep analysis
#   -q, --quiet          Suppress output except errors
#
# ENVIRONMENT:
#   CLAUDE_SESSION_ID    - Current session ID (provided by Claude Code)
#   BOX_DEEP_ANALYSIS    - Set to "true" to enable headless Claude analysis
#

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

ANALYTICS_DIR="${HOME}/.claude/analytics"
BOXES_FILE="${ANALYTICS_DIR}/boxes.jsonl"
INDEX_FILE="${ANALYTICS_DIR}/box-index.json"
ANALYSES_FILE="${ANALYTICS_DIR}/session-analyses.jsonl"
SCRIPTS_DIR="${HOME}/.claude/scripts"

SESSION_ID="${CLAUDE_SESSION_ID:-}"
BACKFILL_MODE=false
DEEP_ANALYSIS="${BOX_DEEP_ANALYSIS:-false}"
QUIET=false

# Thresholds
INDEX_MIN_SCORE=60
MAX_INDEXED_BOXES=100

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

log() {
    [[ "$QUIET" == "true" ]] || echo "[session-end] $*" >&2
}

error() {
    echo "[session-end] ERROR: $*" >&2
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument Parsing
# ─────────────────────────────────────────────────────────────────────────────

show_help() {
    grep '^#' "$0" | grep -v '#!/' | sed 's/^# \?//' | head -20
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)    show_help ;;
            -s|--session) SESSION_ID="$2"; shift 2 ;;
            -a|--all)     BACKFILL_MODE=true; shift ;;
            -d|--deep)    DEEP_ANALYSIS=true; shift ;;
            -q|--quiet)   QUIET=true; shift ;;
            *)            echo "Unknown option: $1"; exit 1 ;;
        esac
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# Box Extraction
# ─────────────────────────────────────────────────────────────────────────────

extract_session_boxes() {
    local session_id="$1"

    if [[ ! -f "$BOXES_FILE" ]]; then
        echo "[]"
        return
    fi

    jq -s --arg sid "$session_id" '
        [.[] | select(.context.session_id == $sid)]
    ' "$BOXES_FILE"
}

extract_unscored_boxes() {
    if [[ ! -f "$BOXES_FILE" ]]; then
        echo "[]"
        return
    fi

    # Get list of already-scored box IDs from index
    local scored_ids="[]"
    if [[ -f "$INDEX_FILE" ]]; then
        scored_ids=$(jq '[.boxes[].id // empty]' "$INDEX_FILE" 2>/dev/null || echo "[]")
    fi

    # Extract boxes not in the scored list
    jq -s --argjson scored "$scored_ids" '
        [.[] | . + {id: "\(.context.session_id)_\(.context.turn_number)"}] |
        [.[] | select(.id as $id | $scored | index($id) | not)]
    ' "$BOXES_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
# Scoring & Indexing
# ─────────────────────────────────────────────────────────────────────────────

score_boxes() {
    local boxes="$1"

    # Get current repo for context scoring
    local current_repo=""
    if git rev-parse --git-dir &>/dev/null; then
        current_repo=$(git remote get-url origin 2>/dev/null | sed -E 's|^(https?://\|git@)||; s|:|/|; s|\.git$||' || echo "")
    fi

    # Use score-boxes.sh if available, otherwise inline scoring
    if [[ -x "${SCRIPTS_DIR}/score-boxes.sh" ]]; then
        echo "$boxes" | "${SCRIPTS_DIR}/score-boxes.sh" -r "$current_repo" -t "$INDEX_MIN_SCORE"
    else
        # Inline scoring (simplified)
        echo "$boxes" | jq --argjson threshold "$INDEX_MIN_SCORE" '
            def score_box:
                . as $box |
                {
                    "Reflection": 90, "Warning": 90, "Pushback": 85, "Assumption": 80,
                    "Choice": 70, "Completion": 70, "Concern": 65, "Confidence": 60,
                    "Decision": 55, "Sycophancy": 50, "Suggestion": 45, "Quality": 40, "FollowUps": 35
                } as $bases |
                ($bases[$box.type] // 40) as $score |
                $box + {score: $score, score_breakdown: {base: $score}};

            map(score_box) | map(select(.score >= $threshold)) | sort_by(-.score)
        '
    fi
}

update_index() {
    local scored_boxes="$1"
    local now
    now=$(date -Iseconds)

    # Initialize index if needed
    if [[ ! -f "$INDEX_FILE" ]]; then
        echo '{
            "version": "2.0.0",
            "last_updated": "'$now'",
            "boxes": [],
            "statistics": {
                "total_processed": 0,
                "total_indexed": 0,
                "compliance_rate": 0,
                "avg_sycophancy_score": 0
            }
        }' > "$INDEX_FILE"
    fi

    # Add IDs to new boxes and merge with existing
    local new_boxes
    new_boxes=$(echo "$scored_boxes" | jq '
        map(. + {id: "\(.context.session_id)_\(.context.turn_number)"})
    ')

    # Merge and deduplicate, keeping highest-scoring boxes
    jq --argjson new "$new_boxes" --arg now "$now" --argjson max "$MAX_INDEXED_BOXES" '
        .last_updated = $now |
        .boxes = (
            (.boxes + $new) |
            group_by(.id) |
            map(max_by(.score)) |
            sort_by(-.score) |
            .[0:$max]
        ) |
        .statistics.total_indexed = (.boxes | length)
    ' "$INDEX_FILE" > "${INDEX_FILE}.tmp" && mv "${INDEX_FILE}.tmp" "$INDEX_FILE"

    log "Index updated: $(echo "$new_boxes" | jq 'length') new boxes"
}

# ─────────────────────────────────────────────────────────────────────────────
# Pattern Detection
# ─────────────────────────────────────────────────────────────────────────────

detect_patterns() {
    local boxes="$1"

    echo "$boxes" | jq '{
        box_count: length,
        by_type: (group_by(.type) | map({type: .[0].type, count: length})),
        has_sycophancy: (map(select(.type == "Sycophancy")) | length > 0),
        avg_sycophancy: (
            [.[] | select(.type == "Sycophancy") | .fields.rating | tonumber? // 10] |
            if length > 0 then add / length else null end
        ),
        assumptions_made: [.[] | select(.type == "Assumption") | .fields.what] | unique,
        pushback_count: ([.[] | select(.type == "Pushback")] | length),
        missing_reasoning: (
            [.[] | select(.type == "Completion" and (.fields.could_improve // "" | test("reason|explain|why"; "i")))] | length
        )
    }'
}

# ─────────────────────────────────────────────────────────────────────────────
# Deep Analysis (Headless Claude)
# ─────────────────────────────────────────────────────────────────────────────

run_deep_analysis() {
    local boxes="$1"
    local session_id="$2"

    # Check if claude CLI is available
    if ! command -v claude &>/dev/null; then
        log "Headless Claude not available, skipping deep analysis"
        return
    fi

    local box_count
    box_count=$(echo "$boxes" | jq 'length')

    # Only run for sessions with sufficient data
    if [[ $box_count -lt 5 ]]; then
        log "Too few boxes ($box_count) for deep analysis, skipping"
        return
    fi

    log "Running deep analysis with headless Claude..."

    local analysis
    analysis=$(claude --print --max-turns 1 --output-format json "
Analyze these response boxes from a Claude Code session. Be concise.

BOXES:
$(echo "$boxes" | jq -c '.')

Provide analysis as JSON with these keys:
- patterns: array of behavioral patterns observed (e.g., 'frequently assumes TypeScript')
- reasoning_gaps: array of areas where reasoning was insufficient
- rule_suggestions: array of potential CLAUDE.md rule updates
- concerns: array of concerning trends (empty if none)
- compliance_score: 0-100 rating of response box compliance

Output ONLY valid JSON, no markdown.
" 2>/dev/null || echo '{"error": "analysis failed"}')

    # Validate and store analysis
    if echo "$analysis" | jq -e '.patterns' &>/dev/null; then
        local record
        record=$(jq -n \
            --arg ts "$(date -Iseconds)" \
            --arg sid "$session_id" \
            --argjson analysis "$analysis" \
            '{ts: $ts, session_id: $sid} + $analysis')

        echo "$record" >> "$ANALYSES_FILE"
        log "Deep analysis stored"

        # Output summary
        echo "$analysis" | jq -r '
            "Analysis Summary:",
            "  Patterns: \(.patterns | join(", "))",
            "  Gaps: \(.reasoning_gaps | join(", "))",
            "  Compliance: \(.compliance_score // "N/A")%"
        '
    else
        log "Deep analysis returned invalid JSON, skipping storage"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main() {
    if ! command -v jq &>/dev/null; then
        error "jq is required but not installed"
        exit 1
    fi

    parse_args "$@"

    # Ensure analytics directory exists
    mkdir -p "$ANALYTICS_DIR"

    local boxes

    if [[ "$BACKFILL_MODE" == "true" ]]; then
        log "Backfill mode: processing all unscored boxes..."
        boxes=$(extract_unscored_boxes)
    elif [[ -n "$SESSION_ID" ]]; then
        log "Processing session: $SESSION_ID"
        boxes=$(extract_session_boxes "$SESSION_ID")
    else
        log "No session ID provided, processing recent unscored boxes..."
        boxes=$(extract_unscored_boxes)
    fi

    local box_count
    box_count=$(echo "$boxes" | jq 'length')

    if [[ $box_count -eq 0 ]]; then
        log "No boxes to process"
        exit 0
    fi

    log "Found $box_count boxes to process"

    # Detect patterns
    local patterns
    patterns=$(detect_patterns "$boxes")
    log "Patterns: $(echo "$patterns" | jq -c '{types: .by_type, sycophancy: .avg_sycophancy}')"

    # Score boxes
    local scored_boxes
    scored_boxes=$(score_boxes "$boxes")

    local high_value_count
    high_value_count=$(echo "$scored_boxes" | jq 'length')
    log "High-value boxes (score >= $INDEX_MIN_SCORE): $high_value_count"

    # Update index
    if [[ $high_value_count -gt 0 ]]; then
        update_index "$scored_boxes"
    fi

    # Deep analysis if enabled
    if [[ "$DEEP_ANALYSIS" == "true" ]]; then
        run_deep_analysis "$boxes" "${SESSION_ID:-unknown}"
    fi

    log "Session analysis complete"
}

main "$@"
