# Contributing to Claude Response Boxes

Thank you for your interest in contributing! This document provides guidelines
for contributing to the project.

## How to Contribute

### Reporting Issues

- Check existing issues before creating a new one
- Use a clear, descriptive title
- Include steps to reproduce for bugs
- Describe expected vs actual behavior

### Suggesting New Box Types

When proposing a new box type:

1. Explain the use case it addresses
2. Show how it differs from existing types
3. Provide example output format
4. Consider how it fits the existing taxonomy

### Pull Requests

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Test the install script locally
5. Update documentation if needed
6. Submit a PR with a clear description

### Code Style

- Shell scripts: Use `shellcheck` and follow Google's shell style guide
- Markdown: Use consistent formatting, 80-char lines where practical
- Keep scripts POSIX-compatible where possible

### Testing Changes

Before submitting:

```bash
# Test install script
./install.sh

# Verify files installed correctly
ls -la ~/.claude/rules/response-boxes.md
ls -la ~/.claude/hooks/collect-boxes.sh
ls -la ~/.claude/scripts/analyze-boxes.sh

# Test collection hook
echo "Test response with ⚖️ Choice box" | ~/.claude/hooks/collect-boxes.sh

# Test analysis script
~/.claude/scripts/analyze-boxes.sh --help
```

## Development Setup

```bash
git clone https://github.com/AIntelligentTech/claude-response-boxes.git
cd claude-response-boxes

# Make scripts executable
chmod +x install.sh hooks/*.sh scripts/*.sh
```

## Questions?

Open an issue for questions about contributing.
