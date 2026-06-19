#!/bin/sh
set -e

# claude-wizard installer (v2)
# Installs the wizard skill + the agent roster into your project's .claude/ directory.

SKILL_DIR=".claude/skills/wizard"
REF_DIR=".claude/skills/wizard/reference"
AGENTS_DIR=".claude/agents"
RAW_BASE="https://raw.githubusercontent.com/vlad-ko/claude-wizard/main"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

printf '\n'
printf '  claude-wizard installer (v2 — multi-agent workflow)\n'
printf '  ===================================================\n'
printf '\n'

# Check we're in a git repo
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    printf '%bError: Not inside a git repository.%b\n' "$RED" "$NC"
    printf 'Run this from the root of your project.\n'
    exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
SKILL_TARGET="${REPO_ROOT}/${SKILL_DIR}"
REF_TARGET="${REPO_ROOT}/${REF_DIR}"
AGENTS_TARGET="${REPO_ROOT}/${AGENTS_DIR}"

# Warn on existing install
if [ -d "$SKILL_TARGET" ]; then
    printf '%bWizard skill already exists at %s/%b\n' "$YELLOW" "$SKILL_DIR" "$NC"
    printf 'Overwrite? (y/N) '
    read -r REPLY
    case "$REPLY" in
        [Yy]*) ;;
        *) printf 'Aborted.\n'; exit 0 ;;
    esac
fi

# Pick a downloader
if command -v curl > /dev/null 2>&1; then
    fetch() { curl -sL "$1" -o "$2"; }
elif command -v wget > /dev/null 2>&1; then
    fetch() { wget -q "$1" -O "$2"; }
else
    printf '%bError: Neither curl nor wget found.%b\n' "$RED" "$NC"
    exit 1
fi

mkdir -p "$SKILL_TARGET" "$REF_TARGET" "$AGENTS_TARGET"

printf 'Downloading skill files...\n'
for file in SKILL.md CHECKLISTS.md PATTERNS.md; do
    fetch "${RAW_BASE}/skill/${file}" "${SKILL_TARGET}/${file}"
    printf '  + %s/%s\n' "$SKILL_DIR" "$file"
done

printf 'Downloading reference docs...\n'
for file in threading-model.md parallel-pipeline.md pr-review-cycle.md; do
    fetch "${RAW_BASE}/reference/${file}" "${REF_TARGET}/${file}"
    printf '  + %s/%s\n' "$REF_DIR" "$file"
done

printf 'Downloading agent roster...\n'
for file in architect backend-expert frontend-expert qa-engineer doc-librarian issue-maintainer domain-user-lens; do
    fetch "${RAW_BASE}/agents/${file}.md" "${AGENTS_TARGET}/${file}.md"
    printf '  + %s/%s.md\n' "$AGENTS_DIR" "$file"
done

printf '\n'
printf '%bInstalled successfully!%b\n' "$GREEN" "$NC"
printf '\n'
printf 'Usage:\n'
printf '  Type /wizard in Claude Code to activate architect mode.\n'
printf '\n'
printf 'Next step (IMPORTANT):\n'
printf '  agents/domain-user-lens.md is a TEMPLATE. Copy it once per user persona in\n'
printf '  your product (e.g. admin-lens.md, end-user-lens.md) and fill in each\n'
printf "  persona's real surfaces, rules, and risks. See the README.\n"
printf '\n'
printf 'Tip: customize SKILL.md and the backend/frontend agents to point at your\n'
printf '     project conventions, then keep your CLAUDE.md sharp — the agents read it.\n'
printf '\n'
