#!/usr/bin/env bash
#
# validate-response.sh - Stop hook for response validation
#
# Validates Claude's response before allowing completion. Blocks if required
# elements are missing from substantive responses.
#
# EXIT CODES:
#   0 - Validation passed (or skipped for non-substantive response)
#   2 - Validation failed (blocks completion with feedback)
#
# ENVIRONMENT:
#   CLAUDE_TRANSCRIPT_PATH - Path to session transcript (provided by Claude Code)
#   BOX_VALIDATION_STRICT  - Set to "true" for strict mode (optional)
#
# CONFIGURATION:
#   ~/.claude/config/validation-rules.json - Custom validation rules (optional)
#

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

# Minimum character count to consider response "substantive"
MIN_SUBSTANTIVE_CHARS=300

# Patterns that indicate non-substantive responses (skip validation)
SKIP_PATTERNS=(
    "^Done\.$"
    "^Completed\.$"
    "^File (created|updated|written)"
    "^Command executed"
    "^Here's the content"
    "^Reading file"
)

# Required boxes for substantive responses
REQUIRED_BOXES=("🪞")  # Sycophancy always required

# Reasoning indicators (at least one must be present)
REASONING_PATTERNS="(because|since|the reason|therefore|this means|in order to|which ensures|this approach|I chose|selected .* over)"

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

log() {
    echo "[validate-response] $*" >&2
}

# Extract last assistant message from transcript
get_last_response() {
    local transcript="$1"

    if [[ ! -f "$transcript" ]]; then
        echo ""
        return
    fi

    # Handle both JSON array and JSONL formats
    if head -1 "$transcript" | grep -q '^\['; then
        # JSON array format
        jq -r '[.[] | select(.type == "assistant")] | last | .content // ""' "$transcript" 2>/dev/null || echo ""
    else
        # JSONL format - get last assistant message
        jq -rs '[.[] | select(.type == "assistant")] | last | .content // ""' "$transcript" 2>/dev/null || echo ""
    fi
}

# Check if response should skip validation
should_skip() {
    local response="$1"
    local char_count=${#response}

    # Skip short responses
    if [[ $char_count -lt $MIN_SUBSTANTIVE_CHARS ]]; then
        return 0
    fi

    # Skip if matches any skip pattern
    for pattern in "${SKIP_PATTERNS[@]}"; do
        if echo "$response" | head -5 | grep -qE "$pattern"; then
            return 0
        fi
    done

    return 1
}

# Check for required boxes
check_required_boxes() {
    local response="$1"
    local missing=()

    for box in "${REQUIRED_BOXES[@]}"; do
        if ! echo "$response" | grep -q "$box"; then
            case "$box" in
                "🪞") missing+=("🪞 Sycophancy box (required for all substantive responses)") ;;
                *) missing+=("$box box") ;;
            esac
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "${missing[@]}"
        return 1
    fi
    return 0
}

# Check for reasoning indicators
check_reasoning() {
    local response="$1"

    # Check if response contains reasoning patterns
    if echo "$response" | grep -qiE "$REASONING_PATTERNS"; then
        return 0
    fi

    # Check if response has decision/choice/assumption boxes (which contain reasoning)
    if echo "$response" | grep -qE "(⚖️|🎯|💭)"; then
        return 0
    fi

    return 1
}

# Check for potential box candidates (decisions made but not documented)
check_undocumented_decisions() {
    local response="$1"
    local warnings=()

    # Check for choice-like language without Choice box
    if echo "$response" | grep -qiE "(I chose|I selected|I decided to use|I went with|picking .* over)" && \
       ! echo "$response" | grep -q "⚖️"; then
        warnings+=("Detected choice language but no ⚖️ Choice box - consider adding one")
    fi

    # Check for assumption-like language without Assumption box
    if echo "$response" | grep -qiE "(I assumed|assuming|I'll assume|presumably)" && \
       ! echo "$response" | grep -q "💭"; then
        warnings+=("Detected assumption language but no 💭 Assumption box - consider adding one")
    fi

    if [[ ${#warnings[@]} -gt 0 ]]; then
        printf '%s\n' "${warnings[@]}"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Main Validation
# ─────────────────────────────────────────────────────────────────────────────

validate() {
    local transcript="${CLAUDE_TRANSCRIPT_PATH:-}"

    # No transcript available - allow completion
    if [[ -z "$transcript" ]]; then
        log "No transcript available, skipping validation"
        exit 0
    fi

    # Get last response
    local response
    response=$(get_last_response "$transcript")

    if [[ -z "$response" ]]; then
        log "No response found in transcript, skipping validation"
        exit 0
    fi

    # Check if should skip
    if should_skip "$response"; then
        log "Response is non-substantive (${#response} chars), skipping validation"
        exit 0
    fi

    log "Validating substantive response (${#response} chars)..."

    local failures=()
    local warnings=()

    # Check required boxes
    local missing_boxes
    if ! missing_boxes=$(check_required_boxes "$response"); then
        failures+=("$missing_boxes")
    fi

    # Check reasoning (only in strict mode or if no boxes present)
    if [[ "${BOX_VALIDATION_STRICT:-false}" == "true" ]] || \
       ! echo "$response" | grep -qE "(⚖️|🎯|💭|📊|↩️|⚠️|💡|🚨)"; then
        if ! check_reasoning "$response"; then
            failures+=("Missing reasoning explanation - explain WHY, not just WHAT you did")
        fi
    fi

    # Check for undocumented decisions (warnings only)
    local undoc_warnings
    undoc_warnings=$(check_undocumented_decisions "$response")
    if [[ -n "$undoc_warnings" ]]; then
        while IFS= read -r warning; do
            warnings+=("$warning")
        done <<< "$undoc_warnings"
    fi

    # Report results
    if [[ ${#failures[@]} -gt 0 ]]; then
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        echo "  RESPONSE VALIDATION FAILED"
        echo "═══════════════════════════════════════════════════════════════"
        echo ""
        echo "Missing required elements:"
        for failure in "${failures[@]}"; do
            echo "  ✗ $failure"
        done
        echo ""

        if [[ ${#warnings[@]} -gt 0 ]]; then
            echo "Additional suggestions:"
            for warning in "${warnings[@]}"; do
                echo "  → $warning"
            done
            echo ""
        fi

        echo "Add the missing elements before completing your response."
        echo ""
        echo "═══════════════════════════════════════════════════════════════"
        exit 2  # Block completion
    fi

    # Report warnings if any
    if [[ ${#warnings[@]} -gt 0 ]]; then
        log "Validation passed with suggestions:"
        for warning in "${warnings[@]}"; do
            log "  → $warning"
        done
    else
        log "Validation passed"
    fi

    exit 0
}

# ─────────────────────────────────────────────────────────────────────────────
# Entry Point
# ─────────────────────────────────────────────────────────────────────────────

validate
