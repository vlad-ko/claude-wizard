# Quick Reference Checklists

## Pre-Implementation Checklist

- [ ] Read CLAUDE.md
- [ ] Fast-forwarded local `main` (a stale checkout makes merged work look absent)
- [ ] Read relevant project docs
- [ ] Assessed complexity (simple/medium/complex) and ran the complexity gate (band 1/2/3)
- [ ] Created/found an issue (for medium+ tasks)
- [ ] Checked for an existing PR AND an uncommitted worktree before branching
- [ ] Reproduced the runtime error first (if the issue describes one)
- [ ] Created todo list with phases
- [ ] Verified all methods/APIs exist (grep/search)
- [ ] Identified patterns to follow
- [ ] Listed files to modify

## Phase-2 Design Audits (run the ones that apply)

- [ ] **Three-Outcome Audit** — the change produces a verdict → `pass` / `fail` / `inconclusive`; samples counted separately; a genuine `0` distinguishable from no-sample
- [ ] **New-Dimension Audit** — the change adds a mode/flag/scope/state → every pre-existing enforcement point on the touched data enumerated and propagated
- [ ] **Expression-Site Inventory** — the change alters a derived fact → every site that expresses it listed; N > 1 collapses to ONE authoritative expression
- [ ] For every new count/denominator, the SET each side ranges over is stated

## Decomposition Checklist (multi-concern work)

- [ ] Phased plan FILED on the issue before any builder is briefed
- [ ] Every instance the sweep found is on the ledger (as a phase or a linked filed issue)
- [ ] One ledger form only — checkboxes OR native sub-issues, never mixed
- [ ] Each phase has ONE owner; must-not-batch phases marked
- [ ] Release-gate disposition on every finding, if a gate is open (fix now / flag-gate / defer)
- [ ] Decision phases complete when the answer is recorded, not at a merge

## TDD Checklist

- [ ] Wrote failing test FIRST (RED); it fails for the right reason
- [ ] Implemented minimal code (GREEN)
- [ ] Assertions target the STATE CHANGE, not the call
- [ ] Fixture quantities that could diverge are deliberately UNEQUAL
- [ ] Teeth verified by a ONE-LINE mutation: changed a line, saw RED, edited it back, saw GREEN, `git diff` clean
- [ ] Never deleted/moved/renamed a file to force RED
- [ ] Added boundary cases (0, 1, -1, null, empty)
- [ ] Tested in the right layer (server / client / browser); shape rules went to a linter rule, not a test
- [ ] Pinned fixtures and the clock
- [ ] A blocking test that encoded the defect was rewritten AND named in the PR

## Implementation Checklist

- [ ] Using constants/enums, not hard-coded strings
- [ ] Using the project's logging/error patterns
- [ ] Input validation complete (server-side, always)
- [ ] Error handling complete; no `catch` that returns a default
- [ ] Race conditions checked for shared state (lock-and-read inside the transaction)
- [ ] Transaction side-effects considered (error state persists outside the transaction)
- [ ] Frontend/backend data contract defined before coding either side
- [ ] Concurrent agents own non-overlapping file lists; `git add <paths>`, never `-A`

## Pre-Commit Checklist

- [ ] All acceptance criteria addressed
- [ ] No hard-coded values that should be constants
- [ ] No assumptions made without verification
- [ ] All edge cases handled
- [ ] No security vulnerabilities
- [ ] **No absence rendered as a value** — every read that can be missing/empty/failed refuses; no consumer turns it back into a default
- [ ] **Mechanism removed, not guarded** — highest rung taken; if only a guard was possible, the PR says so and names the follow-up
- [ ] **Adjacency check** — outward (where else is each stated fact expressed) + inward (which guard proves each relied-on fact, and can it fire here); the `### Adjacency check` block is in the PR body
- [ ] Tests cover new functionality; affected suite passes locally; static analysis clean
- [ ] Documentation updated; touched docs checked for adopted stale claims
- [ ] Issue acceptance-criteria checkboxes updated (at merge time)
- [ ] PR title uses a conventional-commit prefix
- [ ] No AI-attribution trailer on the commit or PR body

## Adversarial Questions

1. What happens if this runs twice concurrently?
2. What if the input is null? Empty? Zero? Negative? Huge?
3. If a read comes back empty or fails, what number does the user see — and can they tell it from a measured one?
4. Which test would go red if I broke this on purpose? Did I check, or am I assuming?
5. What assumptions am I making that could be wrong?
6. If I were trying to break this, how would I?
7. What other code touches this same data?
8. What did I just make true — and where else was that already stated?
9. Does any code throw inside a transaction after creating records that should persist?
10. Could a new caller written next year still do the thing this fix prevents?
11. Would I be embarrassed if this broke in production?

## Complexity-Gate Quick Reference (delegated mode)

Classify on structural signals, not keywords:

| Band | Triggers (highest-first) | Route |
|---|---|---|
| **Band 1** | < 3 AC AND single domain AND no shared-state AND no lifecycle | ONE general-purpose subagent — no ensemble |
| **Band 3** | 3+ AC, OR 2+ builder-distinct domains, OR a shared-state mutation, OR a lifecycle transition | FULL ensemble |
| **Band 2** | the middle (e.g. exactly 2 AC, or a single domain with an adjacent smell) | Orchestrator judgment — default smaller, escalate on a surfaced gap |

A shared-surface touch (a layout/predicate/style/route more than one persona reaches) doesn't
change the band but triggers a cross-actor leak-scoping lens pass. **The band decides how many
AGENTS; decomposition decides how many PRs.**

## Wake Checklist (orchestrator — every push, subagent return, user turn, PR-state question)

- [ ] Broken-main emergency check
- [ ] Sweep every spawned worktree (ahead+clean → push; dirty+no commits → take over)
- [ ] `pr-checkin` sweep of the whole lane; ledger written; ESCALATE → `pr-manager`
- [ ] A fixer dispatched for every finding-bearing PR with none in flight and not STUCK
- [ ] Only then: count open PRs; capacity gate (`resource-manager` GO); build ahead to the band
- [ ] User notified (`PushNotification`) of anything only they can do
- [ ] No `ScheduleWakeup` armed except against ONE named pending external state

## PR Review-Cycle Checklist (orchestrator)

- [ ] After every push, waited for the status checks on that SHA
- [ ] Audited all FOUR finding surfaces (inline / review body / issue-level / check-run) with the ONE canonical detector
- [ ] Every finding replied to (fix or false-positive) AND thread resolved, as one step
- [ ] Separated each reviewer's premise from its remedy before applying
- [ ] Every code fix dispatched to the owning specialist — the orchestrator authored none
- [ ] No conflicts; every blocking check green; suite passed on the current SHA
- [ ] Reviewer-quiescence window elapsed + clean re-audit
- [ ] Posted the pre-merge audit comment; declared merge-ready at a named SHA, once (user merges)
- [ ] Accountability lead running (3+ concurrent PRs)

## Clean-Slate Checklist (end of every task)

- [ ] Primary checkout on `main` at `origin/main`, nothing modified or untracked
- [ ] No worktree of a merged PR; merged branches deleted with `-d`, never `-D`
- [ ] Dirty worktrees classified by change type — real edits KEPT and surfaced, never removed blind
- [ ] Lessons that cleared the bar codified this session
