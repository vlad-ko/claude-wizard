# Quick Reference Checklists

## Pre-Implementation Checklist

- [ ] Read CLAUDE.md
- [ ] Read relevant project docs
- [ ] Assessed complexity (simple/medium/complex)
- [ ] Created/found an issue (for medium+ tasks)
- [ ] Checked for an existing PR before branching
- [ ] Created todo list with phases
- [ ] Verified all methods/APIs exist (grep/search)
- [ ] Identified patterns to follow
- [ ] Listed files to modify

## TDD Checklist

- [ ] Wrote failing test FIRST (RED)
- [ ] Test fails for the right reason
- [ ] Implemented minimal code (GREEN)
- [ ] Test passes
- [ ] Added boundary cases (0, 1, -1, null, empty)
- [ ] Added side-effect assertions
- [ ] Tested in the right layer (server / client / browser)
- [ ] Isolated tests from shared state and external dependencies

## Implementation Checklist

- [ ] Using constants/enums, not hard-coded strings
- [ ] Using the project's logging/error patterns
- [ ] Input validation complete (server-side, always)
- [ ] Error handling complete
- [ ] Race conditions checked for shared state (lock-and-read inside the transaction)
- [ ] Transaction side-effects considered (error state persists outside the transaction)
- [ ] Frontend/backend data contract defined before coding either side

## Pre-Commit Checklist

- [ ] All acceptance criteria addressed
- [ ] No hard-coded values that should be constants
- [ ] No assumptions made without verification
- [ ] All edge cases handled
- [ ] No security vulnerabilities
- [ ] Tests cover new functionality; affected suite passes locally
- [ ] Documentation updated
- [ ] Issue acceptance-criteria checkboxes updated
- [ ] PR title uses a conventional-commit prefix
- [ ] No AI-attribution trailer on the commit or PR body

## Adversarial Questions

1. What happens if this runs twice concurrently?
2. What if the input is null? Empty? Zero? Negative? Huge?
3. What assumptions am I making that could be wrong?
4. If I were trying to break this, how would I?
5. What other code touches this same data?
6. Does any code throw inside a transaction after creating records that should persist?
7. Would I be embarrassed if this broke in production?

## Complexity-Gate Quick Reference (delegated mode)

Classify on structural signals, not keywords:

| Band | Triggers (highest-first) | Route |
|---|---|---|
| **Band 1** | < 3 AC AND single domain AND no shared-state AND no lifecycle | ONE general-purpose subagent — no ensemble |
| **Band 3** | 3+ AC, OR 2+ builder-distinct domains, OR a shared-state mutation, OR a lifecycle transition | FULL ensemble |
| **Band 2** | the middle (e.g. exactly 2 AC, or a single domain with an adjacent smell) | Orchestrator judgment — default smaller, escalate on a surfaced gap |

A shared-surface touch (a layout/predicate/style/route more than one persona reaches) doesn't
change the band but triggers a cross-actor leak-scoping lens pass.

## PR Review-Cycle Checklist (orchestrator)

- [ ] After every push, waited for the status checks on that SHA
- [ ] Audited all three finding surfaces (inline / review body / issue-level)
- [ ] Every finding replied to (fix or false-positive) and thread resolved
- [ ] Separated each reviewer's premise from its remedy before applying
- [ ] No conflicts; every blocking check green; full suite passed on the current SHA
- [ ] Patch-coverage at target
- [ ] Reviewer-quiescence window elapsed + clean re-audit
- [ ] Posted the pre-merge audit comment; declared merge-ready (user merges manually)
