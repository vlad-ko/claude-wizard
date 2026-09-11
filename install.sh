#!/bin/sh
set -e

# claude-wizard installer (v3)
# Installs the wizard skill, its reference docs, and the agent roster into your
# project's .claude/ directory.

SKILL_DIR=".claude/skills/wizard"
REF_DIR=".claude/skills/wizard/reference"
AGENTS_DIR=".claude/agents"
# Overridable so a branch can be smoke-tested before merge:
#   CLAUDE_WIZARD_RAW_BASE=.../claude-wizard/<branch> ./install.sh
RAW_BASE="${CLAUDE_WIZARD_RAW_BASE:-https://raw.githubusercontent.com/vlad-ko/claude-wizard/main}"

SKILL_FILES="SKILL.md CHECKLISTS.md PATTERNS.md"
REFERENCE_FILES="threading-model.md parallel-pipeline.md pr-review-cycle.md \
complexity-gate.md ensemble-dispatch.md phased-decomposition.md \
tests-assert-behavior.md absence-is-not-a-value.md remove-the-mechanism.md adjacency-check.md \
context-economics.md capacity-and-worktrees.md accountability-and-review-channels.md \
codify-the-lesson.md domain-user-lens.template.md"
AGENT_FILES="architect backend-expert frontend-expert qa-engineer doc-librarian issue-maintainer \
backlog-manager pr-checkin pr-manager resource-manager accountability-lead report-maker"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

printf '\n'
printf '  claude-wizard installer (v3 — discipline with teeth)\n'
printf '  ====================================================\n'
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

# Pick a downloader.
# -f/--fail (curl) and the default wget behavior make an HTTP error (404/500)
# a non-zero exit instead of silently writing the server's error body into the
# destination file. download() adds a non-empty check as belt-and-suspenders so
# a partial/empty write also aborts under `set -e` before we claim success.
if command -v curl > /dev/null 2>&1; then
    fetch() { curl -fsSL "$1" -o "$2"; }
elif command -v wget > /dev/null 2>&1; then
    fetch() { wget -q "$1" -O "$2"; }
else
    printf '%bError: Neither curl nor wget found.%b\n' "$RED" "$NC"
    exit 1
fi

# Download a single file and verify it landed non-empty. Any failure exits 1,
# which `set -e` propagates so "Installed successfully!" can never print after
# a broken download.
download() {
    if ! fetch "$1" "$2"; then
        printf '%bError: failed to download %s%b\n' "$RED" "$1" "$NC"
        exit 1
    fi
    if [ ! -s "$2" ]; then
        printf '%bError: downloaded file is empty: %s%b\n' "$RED" "$1" "$NC"
        exit 1
    fi
}

mkdir -p "$SKILL_TARGET" "$REF_TARGET" "$AGENTS_TARGET"

printf 'Downloading skill files...\n'
for file in $SKILL_FILES; do
    download "${RAW_BASE}/skill/${file}" "${SKILL_TARGET}/${file}"
    printf '  + %s/%s\n' "$SKILL_DIR" "$file"
done

printf 'Downloading reference docs...\n'
for file in $REFERENCE_FILES; do
    download "${RAW_BASE}/skill/reference/${file}" "${REF_TARGET}/${file}"
    printf '  + %s/%s\n' "$REF_DIR" "$file"
done

printf 'Downloading agent roster...\n'
for file in $AGENT_FILES; do
    download "${RAW_BASE}/agents/${file}.md" "${AGENTS_TARGET}/${file}.md"
    printf '  + %s/%s.md\n' "$AGENTS_DIR" "$file"
done

printf '\n'
printf '%bInstalled successfully!%b\n' "$GREEN" "$NC"
printf '\n'
printf 'Usage:\n'
printf '  Type /wizard in Claude Code to activate architect mode.\n'
printf '\n'
printf 'Next step (IMPORTANT):\n'
printf '  %s/domain-user-lens.template.md is a TEMPLATE.\n' "$REF_DIR"
printf '  Copy it into %s/ once per user persona in your product (set a\n' "$AGENTS_DIR"
printf '  unique name: in each copy, e.g. admin-lens.md, end-user-lens.md) and fill in\n'
printf "  that persona's real surfaces, rules, and risks. See the README.\n"
printf '\n'
printf 'Tip: keep your CLAUDE.md sharp and SHORT — every agent reads it on every call,\n'
printf '     so state each rule as a summary + pointer to the doc that holds the method.\n'
printf '\n'
