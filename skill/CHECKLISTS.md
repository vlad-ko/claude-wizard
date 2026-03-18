# Quick Reference Checklists

## Pre-Implementation Checklist

- [ ] Read CLAUDE.md
- [ ] If CLAUDE.md references external docs: read every referenced document (all of them, no exceptions)
- [ ] If no CLAUDE.md: scan repo root and docs/ for README, CONTRIBUTING, architecture docs, test guides
- [ ] Assessed complexity (simple/medium/complex)
- [ ] Created/found GitHub issue (for medium+ tasks)
- [ ] Created todo list with phases
- [ ] Verified all methods/APIs exist (grep/search)
- [ ] Identified patterns to follow
- [ ] Listed files to modify

## TDD Checklist (New Features)

- [ ] Wrote failing test FIRST (RED)
- [ ] Test fails for the right reason
- [ ] Implemented minimal code (GREEN)
- [ ] Test passes
- [ ] Refactored: method length, class size, naming, abstraction level (REFACTOR)
- [ ] Added boundary condition tests (0, 1, -1, null, empty)
- [ ] Added side effect assertions
- [ ] Isolated tests from external dependencies

## TDD Checklist (Bug Fixes)

- [ ] Diagnosed root cause and mapped affected code paths
- [ ] Checked whether the same pattern exists elsewhere
- [ ] Wrote test that reproduces the bug (RED)
- [ ] Test fails because of the bug
- [ ] Applied fix (GREEN)
- [ ] Test passes
- [ ] Refactored to address the design pressure that enabled the bug (REFACTOR)
- [ ] Wrote tests for any related instances of the same pattern

## Implementation Checklist

- [ ] Using constants/enums, not hard-coded strings
- [ ] Using project's logging patterns
- [ ] Following project's UI framework conventions
- [ ] Input validation is complete
- [ ] Error handling is complete
- [ ] Race conditions checked for shared state
- [ ] Transaction side-effects considered

## Design Heuristics Checklist

- [ ] Methods under 5-8 lines where possible
- [ ] One level of abstraction per function
- [ ] Classes under 100 lines
- [ ] Each class has one reason to change
- [ ] No more than 4 parameters per method
- [ ] Dependencies point inward toward business logic
- [ ] Interfaces designed from the caller's perspective

## Pre-Commit Checklist

- [ ] All acceptance criteria addressed
- [ ] No hard-coded values that should be constants
- [ ] No assumptions made without verification
- [ ] All edge cases handled
- [ ] No security vulnerabilities
- [ ] Tests cover new functionality
- [ ] Full test suite passes
- [ ] Documentation updated where behaviour changed
- [ ] Design heuristics applied (method length, class size, dependency direction)
- [ ] GitHub issue updated
- [ ] Scope respected - no changes outside the task

## Adversarial Test Coverage Verification

Before committing, confirm that tests exist for each of these. If any are missing, write them.

1. What happens if this runs twice concurrently? (test exists: yes/no)
2. What if the input is null? Empty? Zero? Negative? Huge? (tests exist: yes/no)
3. What assumptions am I making that could be wrong? (tested: yes/no)
4. If I were trying to break this, how would I? (test exists: yes/no)
5. What other code touches this same data? (interaction tested: yes/no)
6. What happens if this fails partway through? (test exists: yes/no)

## Test Strategy

Run the full test suite before every commit. No exceptions. If the suite is too slow, flag it as a separate problem to address.

## GitHub Issue Commands

```bash
# List issues
gh issue list --search "keyword"

# Create issue
gh issue create --title "Title" --body "Body"

# Update issue body (check acceptance criteria)
gh issue edit <number> --body "..."

# Add comment
gh issue comment <number> --body "Progress update..."

# Add labels
gh issue edit <number> --add-label "in-progress"

# Close issue
gh issue close <number> --comment "Completed in PR #123"
```