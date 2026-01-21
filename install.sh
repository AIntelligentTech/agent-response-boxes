#!/usr/bin/env bash
#
# Claude Response Boxes - Installer v3.0
#
# A metacognitive annotation system for Claude Code responses.
#
# QUICK INSTALL (user-level):
#   curl -sSL https://raw.githubusercontent.com/AIntelligentTech/claude-response-boxes/main/install.sh | bash
#
# PROJECT-LEVEL INSTALL:
#   curl -sSL https://raw.githubusercontent.com/AIntelligentTech/claude-response-boxes/main/install.sh | bash -s -- --project
#
# OPTIONS:
#   --user      Install to ~/.claude/ (DEFAULT)
#   --project   Install to ./.claude/ (current project only)
#   --uninstall Remove installed components
#   --help      Show this help
#

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

RAW_URL="https://raw.githubusercontent.com/AIntelligentTech/claude-response-boxes/main"
VERSION="3.0.0"

USER_CLAUDE_DIR="${HOME}/.claude"
PROJECT_CLAUDE_DIR="./.claude"

INSTALL_SCOPE="user"
CLAUDE_DIR="${USER_CLAUDE_DIR}"
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
    echo -e "${BOLD}        Claude Response Boxes v${VERSION}${NC}"
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Argument Parsing
# ─────────────────────────────────────────────────────────────────────────────

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --user)      INSTALL_SCOPE="user"; CLAUDE_DIR="${USER_CLAUDE_DIR}"; shift ;;
            --project)   INSTALL_SCOPE="project"; CLAUDE_DIR="${PROJECT_CLAUDE_DIR}"; shift ;;
            --uninstall) UNINSTALL=true; shift ;;
            --help|-h)   show_help; exit 0 ;;
            *)           warn "Unknown option: $1"; shift ;;
        esac
    done
}

show_help() {
    grep '^#' "$0" | grep -v '#!/' | sed 's/^# \?//' | head -20
}

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

detect_source() {
    if [[ -f "./output-styles/response-box.md" ]]; then
        SOURCE="local"
        SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    else
        SOURCE="remote"
        SOURCE_DIR=""
    fi
}

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

backup_if_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d-%H%M%S)"
        cp "$file" "$backup"
        info "Backed up: $(basename "$file")"
    fi
}

snippet_exists() {
    local file="$1"
    if [[ -f "$file" ]] && grep -q "PRE-RESPONSE CHECKLIST" "$file"; then
        return 0
    fi
    return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Installation
# ─────────────────────────────────────────────────────────────────────────────

install_output_style() {
    log "Installing output style..."
    mkdir -p "${USER_CLAUDE_DIR}/output-styles"
    get_file "output-styles/response-box.md" "${USER_CLAUDE_DIR}/output-styles/response-box.md"
    log "  → ~/.claude/output-styles/response-box.md"
}

install_rules() {
    log "Installing rules..."
    mkdir -p "${CLAUDE_DIR}/rules"
    get_file "rules/response-boxes.md" "${CLAUDE_DIR}/rules/response-boxes.md"
    log "  → ${CLAUDE_DIR}/rules/response-boxes.md"
}

install_claude_md_snippet() {
    local claude_md="${CLAUDE_DIR}/CLAUDE.md"
    local scope_label
    if [[ "$INSTALL_SCOPE" == "user" ]]; then
        scope_label="Global"
    else
        scope_label="Project"
    fi

    if snippet_exists "$claude_md"; then
        info "Response Box snippet already in CLAUDE.md, skipping..."
        return
    fi

    log "Adding snippet to CLAUDE.md..."

    if [[ ! -f "$claude_md" ]]; then
        echo "# ${scope_label} Claude Code Configuration" > "$claude_md"
        echo "" >> "$claude_md"
    else
        backup_if_exists "$claude_md"
    fi

    if [[ "${SOURCE}" == "local" ]]; then
        cat "${SOURCE_DIR}/config/claude-md-snippet.md" >> "$claude_md"
    else
        curl -sSL "${RAW_URL}/config/claude-md-snippet.md" >> "$claude_md"
    fi

    log "  → Added snippet to ${claude_md}"
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
        "${USER_CLAUDE_DIR}/output-styles/response-box.md"
    )

    for file in "${files_to_remove[@]}"; do
        if [[ -f "$file" ]]; then
            rm "$file"
            log "Removed: $file"
        fi
    done

    warn "Note: CLAUDE.md snippet NOT removed"
    info "Manually remove the Response Box System section from CLAUDE.md"

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
    info "Scope: ${INSTALL_SCOPE}"
    info "Target: ${CLAUDE_DIR}"
    echo ""

    install_output_style
    install_rules
    install_claude_md_snippet

    echo ""
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}Installation complete!${NC}"
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo ""

    echo "Installed:"
    echo "  • Output Style: ~/.claude/output-styles/response-box.md"
    echo "  • Rules:        ${CLAUDE_DIR}/rules/response-boxes.md"
    echo "  • CLAUDE.md:    Updated with pre-response checklist"
    echo ""
    echo "Activate:"
    echo "  /output-style response-box"
    echo ""
    echo "Or set as default in ~/.claude/settings.json:"
    echo "  { \"outputStyle\": \"response-box\" }"
    echo ""
}

main "$@"
