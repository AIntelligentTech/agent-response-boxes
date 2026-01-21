#!/usr/bin/env bash
#
# Claude Response Boxes - Installer v2.0
#
# A metacognitive annotation system for Claude Code responses with
# active enforcement via hooks.
#
# QUICK INSTALL:
#   curl -sSL https://raw.githubusercontent.com/AIntelligentTech/claude-response-boxes/main/install.sh | bash
#
# MANUAL INSTALL:
#   git clone https://github.com/AIntelligentTech/claude-response-boxes.git
#   cd claude-response-boxes && ./install.sh
#
# OPTIONS:
#   --no-hooks      Skip hook configuration (rules only)
#   --hooks-only    Only configure hooks (skip rules/scripts)
#   --uninstall     Remove installed components
#   --help          Show this help
#
# WHAT THIS DOES:
#   1. Copies rules to ~/.claude/rules/
#   2. Copies hooks to ~/.claude/hooks/
#   3. Copies scripts to ~/.claude/scripts/
#   4. Copies config to ~/.claude/config/
#   5. Creates ~/.claude/analytics/ for box tracking
#   6. Adds snippet to ~/.claude/CLAUDE.md (with backup)
#   7. Configures hooks in ~/.claude/settings.json
#

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

REPO_URL="https://github.com/AIntelligentTech/claude-response-boxes"
RAW_URL="https://raw.githubusercontent.com/AIntelligentTech/claude-response-boxes/main"
CLAUDE_DIR="${HOME}/.claude"
VERSION="2.0.0"

# Installation options
INSTALL_HOOKS=true
INSTALL_RULES=true
UNINSTALL=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# ─────────────────────────────────────────────────────────────────────────────
# Logging
# ─────────────────────────────────────────────────────────────────────────────

log()   { echo -e "${GREEN}✓${NC} $*"; }
info()  { echo -e "${BLUE}ℹ${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
error() { echo -e "${RED}✖${NC} $*" >&2; }

header() {
    echo ""
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}        Claude Response Boxes - Installation v${VERSION}${NC}"
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument Parsing
# ─────────────────────────────────────────────────────────────────────────────

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-hooks)    INSTALL_HOOKS=false; shift ;;
            --hooks-only)  INSTALL_RULES=false; shift ;;
            --uninstall)   UNINSTALL=true; shift ;;
            --help|-h)     show_help; exit 0 ;;
            *)             warn "Unknown option: $1"; shift ;;
        esac
    done
}

show_help() {
    grep '^#' "$0" | grep -v '#!/' | sed 's/^# \?//' | head -30
}

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

# Detect if running from curl pipe or local clone
detect_source() {
    if [[ -f "./rules/response-boxes.md" ]]; then
        SOURCE="local"
        SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    else
        SOURCE="remote"
        SOURCE_DIR=""
    fi
}

# Download file from remote or copy from local
get_file() {
    local src="$1"
    local dst="$2"

    mkdir -p "$(dirname "$dst")"

    if [[ "${SOURCE}" == "local" ]]; then
        cp "${SOURCE_DIR}/${src}" "$dst"
    else
        curl -sSL "${RAW_URL}/${src}" -o "$dst"
    fi
}

# Backup file if it exists
backup_if_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d-%H%M%S)"
        cp "$file" "$backup"
        info "Backed up: $(basename "$file")"
    fi
}

# Check if snippet already exists in CLAUDE.md
snippet_exists() {
    local file="$1"
    if [[ -f "$file" ]] && grep -q "PRE-RESPONSE CHECKLIST" "$file"; then
        return 0
    fi
    return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Installation Steps
# ─────────────────────────────────────────────────────────────────────────────

install_rules() {
    log "Installing rules..."
    mkdir -p "${CLAUDE_DIR}/rules"
    get_file "rules/response-boxes.md" "${CLAUDE_DIR}/rules/response-boxes.md"
    log "  → ${CLAUDE_DIR}/rules/response-boxes.md"
}

install_hooks() {
    log "Installing hooks..."
    mkdir -p "${CLAUDE_DIR}/hooks"

    local hooks=(
        "collect-boxes.sh"
        "validate-response.sh"
        "enforce-reminder.sh"
        "inject-context.sh"
    )

    for hook in "${hooks[@]}"; do
        get_file "hooks/${hook}" "${CLAUDE_DIR}/hooks/${hook}"
        chmod +x "${CLAUDE_DIR}/hooks/${hook}"
        log "  → ${CLAUDE_DIR}/hooks/${hook}"
    done
}

install_scripts() {
    log "Installing scripts..."
    mkdir -p "${CLAUDE_DIR}/scripts"

    local scripts=(
        "analyze-boxes.sh"
        "score-boxes.sh"
        "session-end-analyze.sh"
    )

    for script in "${scripts[@]}"; do
        get_file "scripts/${script}" "${CLAUDE_DIR}/scripts/${script}"
        chmod +x "${CLAUDE_DIR}/scripts/${script}"
        log "  → ${CLAUDE_DIR}/scripts/${script}"
    done
}

install_config() {
    log "Installing configuration..."
    mkdir -p "${CLAUDE_DIR}/config"

    get_file "config/scoring-weights.json" "${CLAUDE_DIR}/config/scoring-weights.json"
    log "  → ${CLAUDE_DIR}/config/scoring-weights.json"
}

install_analytics_dir() {
    log "Creating analytics directory..."
    mkdir -p "${CLAUDE_DIR}/analytics"
    touch "${CLAUDE_DIR}/analytics/.gitkeep"
    log "  → ${CLAUDE_DIR}/analytics/"
}

install_claude_md_snippet() {
    local claude_md="${CLAUDE_DIR}/CLAUDE.md"

    if snippet_exists "$claude_md"; then
        info "Response Box System (v2) already in CLAUDE.md, skipping..."
        return
    fi

    # Check for old v1 snippet and offer to upgrade
    if [[ -f "$claude_md" ]] && grep -q "Response Box System" "$claude_md" && ! grep -q "PRE-RESPONSE CHECKLIST" "$claude_md"; then
        warn "Found v1 Response Box snippet in CLAUDE.md"
        info "Please manually update to v2 format from:"
        info "  ${CLAUDE_DIR}/config/claude-md-snippet.md"
        return
    fi

    log "Adding snippet to CLAUDE.md..."

    # Create CLAUDE.md if it doesn't exist
    if [[ ! -f "$claude_md" ]]; then
        echo "# Global Claude Code Configuration" > "$claude_md"
        echo "" >> "$claude_md"
    else
        backup_if_exists "$claude_md"
    fi

    # Append the v2 snippet
    if [[ "${SOURCE}" == "local" ]]; then
        cat "${SOURCE_DIR}/config/claude-md-snippet.md" >> "$claude_md"
    else
        curl -sSL "${RAW_URL}/config/claude-md-snippet.md" >> "$claude_md"
    fi

    log "  → Added v2 snippet to ${claude_md}"
}

configure_hooks() {
    local settings_file="${CLAUDE_DIR}/settings.json"

    log "Configuring hooks in settings.json..."

    # Create settings.json if it doesn't exist
    if [[ ! -f "$settings_file" ]]; then
        echo '{}' > "$settings_file"
    fi

    backup_if_exists "$settings_file"

    # Add hook configuration using jq
    if command -v jq &>/dev/null; then
        local hook_config='{
            "hooks": {
                "Stop": [
                    {
                        "matcher": "",
                        "hooks": [
                            {
                                "type": "command",
                                "command": "~/.claude/hooks/validate-response.sh",
                                "timeout": 5
                            },
                            {
                                "type": "command",
                                "command": "~/.claude/scripts/session-end-analyze.sh -q",
                                "timeout": 30
                            }
                        ]
                    }
                ],
                "PostToolUse": [
                    {
                        "matcher": "",
                        "hooks": [
                            {
                                "type": "command",
                                "command": "~/.claude/hooks/enforce-reminder.sh",
                                "timeout": 2
                            }
                        ]
                    }
                ]
            }
        }'

        # Merge with existing settings (preserving other configurations)
        local current
        current=$(cat "$settings_file")

        # Check if hooks already exist
        if echo "$current" | jq -e '.hooks.Stop' &>/dev/null; then
            warn "Existing Stop hooks found in settings.json"
            info "Please manually merge hook configuration from:"
            info "  See docs/architecture-v2.md for hook configuration"
        else
            echo "$current" | jq --argjson hooks "$hook_config" '. * $hooks' > "${settings_file}.tmp"
            mv "${settings_file}.tmp" "$settings_file"
            log "  → Hooks configured in ${settings_file}"
        fi
    else
        warn "jq not found - cannot auto-configure hooks"
        info "Please manually add hooks to ${settings_file}"
        info "See docs/architecture-v2.md for configuration"
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Uninstall
# ─────────────────────────────────────────────────────────────────────────────

uninstall() {
    echo ""
    echo -e "${BOLD}Uninstalling Claude Response Boxes...${NC}"
    echo ""

    local files_to_remove=(
        "${CLAUDE_DIR}/rules/response-boxes.md"
        "${CLAUDE_DIR}/hooks/collect-boxes.sh"
        "${CLAUDE_DIR}/hooks/validate-response.sh"
        "${CLAUDE_DIR}/hooks/enforce-reminder.sh"
        "${CLAUDE_DIR}/hooks/inject-context.sh"
        "${CLAUDE_DIR}/scripts/analyze-boxes.sh"
        "${CLAUDE_DIR}/scripts/score-boxes.sh"
        "${CLAUDE_DIR}/scripts/session-end-analyze.sh"
        "${CLAUDE_DIR}/config/scoring-weights.json"
    )

    for file in "${files_to_remove[@]}"; do
        if [[ -f "$file" ]]; then
            rm "$file"
            log "Removed: $file"
        fi
    done

    warn "Note: CLAUDE.md snippet and settings.json hooks NOT removed"
    info "Manually remove the Response Box System section from CLAUDE.md"
    info "Manually remove hooks from settings.json"
    echo ""
    log "Uninstall complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main() {
    parse_args "$@"

    if [[ "$UNINSTALL" == "true" ]]; then
        uninstall
        exit 0
    fi

    header
    detect_source

    info "Source: ${SOURCE}"
    info "Target: ${CLAUDE_DIR}"
    echo ""

    if [[ "$INSTALL_RULES" == "true" ]]; then
        install_rules
        install_scripts
        install_config
        install_analytics_dir
        install_claude_md_snippet
    fi

    if [[ "$INSTALL_HOOKS" == "true" ]]; then
        install_hooks
        configure_hooks
    fi

    echo ""
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}Installation complete!${NC}"
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "What's installed:"
    echo "  • Rules:    ~/.claude/rules/response-boxes.md"
    echo "  • Hooks:    ~/.claude/hooks/ (4 enforcement hooks)"
    echo "  • Scripts:  ~/.claude/scripts/ (3 analysis scripts)"
    echo "  • Config:   ~/.claude/config/scoring-weights.json"
    echo ""
    echo "Enforcement active:"
    echo "  • Stop hook validates responses before completion"
    echo "  • PostToolUse hook injects reminders"
    echo "  • Session-end analysis scores and indexes boxes"
    echo ""
    echo "Next steps:"
    echo "  1. Review: less ~/.claude/rules/response-boxes.md"
    echo "  2. Start a new Claude Code session"
    echo "  3. Boxes are now ENFORCED, not just documented"
    echo ""
    echo "Documentation: ${REPO_URL}"
    echo ""
}

main "$@"
