#!/usr/bin/env bash
#
# Claude Response Boxes - Installer
#
# A metacognitive annotation system for Claude Code responses.
#
# QUICK INSTALL:
#   curl -sSL https://raw.githubusercontent.com/AIntelligentTech/claude-response-boxes/main/install.sh | bash
#
# MANUAL INSTALL:
#   git clone https://github.com/AIntelligentTech/claude-response-boxes.git
#   cd claude-response-boxes && ./install.sh
#
# WHAT THIS DOES:
#   1. Copies rules to ~/.claude/rules/
#   2. Copies hooks to ~/.claude/hooks/ (optional)
#   3. Copies scripts to ~/.claude/scripts/
#   4. Adds snippet to ~/.claude/CLAUDE.md (with backup)
#   5. Creates ~/.claude/analytics/ for box tracking
#

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

REPO_URL="https://github.com/AIntelligentTech/claude-response-boxes"
RAW_URL="https://raw.githubusercontent.com/AIntelligentTech/claude-response-boxes/main"
CLAUDE_DIR="${HOME}/.claude"
VERSION="1.0.0"

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
        info "Backed up: $file → $backup"
    fi
}

# Check if snippet already exists in CLAUDE.md
snippet_exists() {
    local file="$1"
    if [[ -f "$file" ]] && grep -q "Response Box System" "$file"; then
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
    get_file "hooks/collect-boxes.sh" "${CLAUDE_DIR}/hooks/collect-boxes.sh"
    chmod +x "${CLAUDE_DIR}/hooks/collect-boxes.sh"
    log "  → ${CLAUDE_DIR}/hooks/collect-boxes.sh"
}

install_scripts() {
    log "Installing scripts..."
    mkdir -p "${CLAUDE_DIR}/scripts"
    get_file "scripts/analyze-boxes.sh" "${CLAUDE_DIR}/scripts/analyze-boxes.sh"
    chmod +x "${CLAUDE_DIR}/scripts/analyze-boxes.sh"
    log "  → ${CLAUDE_DIR}/scripts/analyze-boxes.sh"
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
        info "Response Box System already in CLAUDE.md, skipping..."
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

    # Append the snippet
    cat >> "$claude_md" << 'SNIPPET_EOF'

---

## Response Box System (MANDATORY)

**Full spec:** `~/.claude/rules/response-boxes.md`

**Inline boxes** (use when applicable):

| Box | When |
|-----|------|
| ⚖️ Choice | Selected between alternatives |
| 🎯 Decision | Made judgment call |
| 💭 Assumption | Filled unstated requirement |
| ⚠️ Concern | Potential risk to flag |
| 📊 Confidence | Claim with uncertainty (<90%) |
| ↩️ Pushback | Disagree with user direction |
| 💡 Suggestion | Optional improvement |
| 🚨 Warning | Serious risk |

**End boxes** (max 3, this order):

| Box | When |
|-----|------|
| 📋 Follow Ups | Next steps exist |
| 🏁 Completion | Task being completed |
| ✅ Quality | Code was written |
| 🪞 Sycophancy | ALWAYS (substantive responses) |

**Verbosity:** Prefer more boxes over fewer — missing context is worse than noise.

Skip all boxes for: Simple confirmations, single-action completions, file reads.
SNIPPET_EOF

    log "  → Added to ${claude_md}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main() {
    header
    detect_source

    info "Source: ${SOURCE}"
    info "Target: ${CLAUDE_DIR}"
    echo ""

    install_rules
    install_hooks
    install_scripts
    install_analytics_dir
    install_claude_md_snippet

    echo ""
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}Installation complete!${NC}"
    echo -e "${BOLD}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review the rules: less ~/.claude/rules/response-boxes.md"
    echo "  2. Start a new Claude Code session"
    echo "  3. Claude will now use response boxes automatically"
    echo ""
    echo "Optional:"
    echo "  - Configure hook in Claude Code settings for automatic collection"
    echo "  - Run analysis: ~/.claude/scripts/analyze-boxes.sh"
    echo ""
    echo "Documentation: ${REPO_URL}"
    echo ""
}

main "$@"
