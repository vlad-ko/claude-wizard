# Phased decomposition — file the phases, THEN dispatch

> Loaded on demand by the wizard SKILL. The always-on summary lives in the SKILL body
> ("Phase 2.5: Phased Decomposition"); this file holds the ordered steps, the phase shapes, the
> slicing rules, the ledger forms, the release-gate disposition, and the per-phase builder-brief
> contract. The routing (who produces the plan, who files it, who builds each phase) is
> [`ensemble-dispatch.md`](ensemble-dispatch.md) step 0.5.

## The anti-pattern this closes

**The orchestrator dispatching ONE large improvised fix instead of running gate → decompose →
file phases → dispatch per phase.** Real precedent: two fix agents on two audit findings reached
**20** and **11** modified files in a single worktree each, as one unit of work, heading for one
large PR apiece. The user's correction: do not build a huge blast-radius change in one go — file
the issues, break them into phases, ship them as small PRs. **This applies to new code and to
refactoring, not only to bug fixes.**

Why the existing "prefer small PRs" rule did not bind: it stated a *preference* with no
procedure, no owner, and nothing the orchestrator had to DO before dispatching. A preference loses
to momentum — the agent is mid-fix when the size becomes visible, and by then splitting costs more
than shipping. **An ordered step that must produce a filed artifact before a builder is briefed**
is what makes it binding.

## The order

On any multi-concern finding, audit output, or refactor, the first act **after the complexity
gate** is a **phased plan filed on the issue** — never a builder dispatch.

1. **Gate first.** Take the band from [`complexity-gate.md`](complexity-gate.md). **The gate
   decides how many AGENTS; decomposition decides how many PRs** — independent questions. A
   two-concern task can gate to Band 1 and still ship as two PRs, built in sequence by one
   subagent. What is forbidden at *every* band is one improvised multi-concern dispatch.
2. **Produce the plan.** `architect` on a design fork; the orchestrator directly on a mechanical
   sweep whose inventory already exists.
3. **FILE it.** `issue-maintainer` writes the plan onto the issue — phase checkboxes by default,
   native sub-issues for a genuine epic. **The phase ledger IS the acceptance-criteria ledger.**
4. **Dispatch ONE phase to ONE OWNER.** One brief, one worktree, one PR, one ledger entry, one
   accountable specialist — who may fan out inside the phase where coupling is genuine.
5. **Merge, mark the phase complete AT MERGE-TIME, then the next phase.**

**The hard line: no builder is dispatched before step 3.** A plan that lives only in the
orchestrator's context is not a plan — it does not survive compaction, the next session cannot
read it, and nothing forces the split once a worktree is open and growing.

## Phase shapes — name them, and decomposition becomes a sorting task

| Shape | Produces | Risk | Lands |
|---|---|---|---|
| **Decision** | No code — a product / compliance / architecture answer that changes *what* gets built | — | First; it gates everything downstream |
| **Additive / scaffolding** | A new table, model, service or DTO **plus its own passing tests** — no caller switched, no behavior change | Lowest | Early |
| **Single-concern behavior** | One defect, one seam, its own test — RED locally, merged GREEN | Varies | The bulk of the plan |
| **Integration** | Wires a new seam into an existing caller — behavior moves | Higher | Its OWN PR, never bundled with the scaffolding it consumes |
| **Contract** | The destructive / removal half — the old shape deleted | Deferred | A **later release**, after soak |

- **Decision.** Owned by the `architect` when framing the options needs analysis (a capability
  trace, an invariant map); by the orchestrator when it is a pure product question it can already
  state. Either way the owner **frames and records; it does not decide** — the user answers, and
  the phase completes when the answer is written onto the issue. Real precedent: a plan's Phase 0
  asked whether the system transmitted a value to an external party at all; filing it first kept
  a multi-PR effort from being scoped against an unverified premise. A decision phase blocks only
  its own track — fill the wait with independent work and notify the user.
- **Additive.** Nothing calls it yet, so it cannot regress anything. It ships **with its own
  passing tests**; it is never "a failing test on its own."
- **Single-concern.** If you cannot state the concern in one sentence without "and", it is two.
- **Integration.** Where behavior actually moves, so it carries the risk the scaffolding did not.
- **Contract.** Expand/contract generalized from schema to code — see "Refactors" below.

**RED is a LOCAL, pre-merge discipline; a merged PR is always GREEN.** Write the failing test,
watch it fail, implement; test and implementation land in the SAME PR. A standalone failing test
is never a phase and never merges — it would make main red. "Lowest risk first" therefore orders
*phases*, not TDD steps. The one legitimate test-only PR is a green characterization test that
pins behavior a later phase will change.

## Slicing rules

- **One concern per PR, independently mergeable** against main — never stacked, never "merge
  these two together or it breaks."
- **Every PR leaves the codebase working.** **If two changes genuinely cannot stand apart, they
  are ONE phase — say so in the plan.** Over-fragmentation is its own failure: N PRs that each need
  the others is a large PR with extra review overhead.
- **Lowest risk first.** Scaffolding before the behavior change that consumes it, so the risky
  phase lands on a base that already carries its scaffolding, reviewed and soaked.
- **Explicitly flag what MUST NOT be batched.** A phase touching a payment path or
  already-settled external state merges alone and soaks — mark it "merge alone, soak" in the plan
  so a later session cannot batch it by accident. A duplicate external order is not recoverable by
  a revert.
- **Size is a cue, not a cap.** A unit of work heading past a handful of files across **more than
  one concern** is the cue to stop and decompose. It is deliberately not a file count: one coherent
  concern can legitimately touch many files (a rename, a propagation sweep), and a bright-line cap
  gets gamed by splitting one concern across two PRs while a multi-concern six-file PR sails
  through. Judge on concern count.
- **"A phase needing two specialists is really two phases" is a HEURISTIC.** It is the cue to
  test whether the coupling is real: *can each half merge on its own and leave the codebase
  working?* Yes → two phases. No → one phase with a fan-out, stated in the plan so a later session
  does not re-split it. The usual answer is still "two phases."

## Find broadly, fix completely, ship incrementally

**Systemic-fix discipline defines DONE; phasing is the ROUTE to it, never an exemption.** A pattern
is not fixed until every instance is fixed. **What is narrow is the PR, never the fix.**

| Failure mode | What it looks like | Why it is wrong |
|---|---|---|
| **One giant PR** | Every instance at once — 20 files, one review | Unreviewable, not revertable per concern. The failure this file was written for. |
| **One instance, issue closed** | The site in front of you fixed; siblings never filed, or filed and forgotten | The pattern survives and the next author hits it. Trading mode 1 for mode 2 is not progress. |

The **sweep** casts wide — every sibling, every call site, every consumer. The breadth lands in
the **issue**: the COMPLETE inventory, each instance a phase or its own filed issue. The narrowness
lands in each **PR**. **The issue's phase list IS the instance inventory** — "we got all of them"
becomes verifiable by reading the ledger rather than trusting a claim. The issue stays OPEN until
every phase resolves — landed, or explicitly linked out. **A deferred sibling never leaves the
parent's inventory:** file it as its own issue and keep a ledger entry linking it
(`- [x] Instance N: <site> — deferred, tracked in <issue>`); the *filing* keeps the obligation
alive, and only an unresolved box holds the parent open. **A builder that finds an out-of-scope
sibling RETURNS it as a finding to file** — never fixes it in place (mode 1), never drops it
(mode 2); the orchestrator routes it to `issue-maintainer`.

## Ledger form and completion

Two forms, one per issue, **never mixed** — they complete by different mechanisms, and a ledger
that can be read two ways gets read the wrong way.

| Form | Use when | Completion | Parent closes when |
|---|---|---|---|
| **Checkboxes** (default) | Slices of ONE unit of work with a shared AC set | The orchestrator flips `- [ ]` → `- [x]` **at merge-time**, not batched to close-time | Every box is checked |
| **Native sub-issues** (epics only) | Each phase is independently ticketed work with its own AC, owner and lifecycle | The sub-issue CLOSES when its close condition is met — usually at its PR's merge via `Fixes <sub-issue>`; by hand when the condition outlives the merge | Every sub-issue is closed (the host's native progress count is the ledger) |

Under sub-issues, the merge-time flip still governs each sub-issue's OWN checkboxes. Write the
closing keyword **only** when the merge itself satisfies the close condition — an auto-close on a
phase that still needs a deploy or a re-walk puts a false "complete" on the ledger. **A decision
phase completes when its answer is recorded** — flip its box or close its sub-issue then, so the
ledger cannot stall the next phase behind a merge that is never coming.

## The release-gate disposition — "unfiled" is never one

Fires only when a **release gate** is open (a launch, a compliance deadline, a cutover); absent a
gate, the ordinary filing convention stands. Real precedent: in one session the orchestrator filed
45 issues against 34 closed with a launch pending. The reflex correction — *stop filing* — was
rejected too: a gap never recorded is forgotten, the **worse** failure, because an over-filed item
can be re-prioritised and an unrecorded one cannot. The defect was **undifferentiated** filing.
So every real finding is RECORDED *and* carries a DISPOSITION, asked in this order:

1. **FIX NOW** — the harm is **already occurring** on a path that already runs. The test is the
   harm, not the domain: data loss, corruption and production unavailability are FIX NOW anywhere.
2. **FLAG-GATE** — the harm is reachable **only** through a UI trigger that can be made
   unreachable ("only" is the whole word). Hide the surface and **the work stays OWED**; the flag's
   removal condition is that work completing. A flag over a button while a scheduled job still
   walks the path is a FIX NOW misfiled.
3. **DEFER** — not occurring, not reachable; recorded, explicitly post-release, still tracked.

It is **VISIBLE in the tracker** as a label, one per branch, applied at filing time — and, when
the gate first opens, proposed over the already-open backlog in priority order, stopping where a
deferral adds no information. It is **the user's call**: the orchestrator proposes with per-item
reasoning, never assigns unilaterally. **A disposition is NOT an exemption from the systemic-fix
rule** — "deferred" is exactly the word someone will reach for to close an obligation early. The
ledger still names the instance; FLAG-GATE is a guard in the sense of
[`remove-the-mechanism.md`](remove-the-mechanism.md), which leaves the work owed; a disposition
schedules work and never declines it.

## Refactors and new features decompose identically

A refactor is not one atomic act. It is expand/contract generalized from schema to code:
**(1) additive** — the new shape beside the old, no caller switched; **(2) integration, one caller
at a time** — each its own PR, both shapes coexisting on purpose; **(3) contract, a later release**
— delete the old shape only once no caller reads it (a rolling deploy keeps the previous revision
serving, and a caller you missed surfaces during coexistence, not after the delete). A new feature
runs the same order: scaffolding, then the behavior seam, then the integration that makes it
reachable.

## The per-phase builder-brief contract

Builders see only the brief plus the auto-loaded instruction files — never this document. Every
per-phase brief carries these clauses in substance:

1. **The phase's single concern, and what is explicitly OUT of scope.** Name the sibling findings
   and state that they are other phases — a builder that does not know a sibling is filed will
   absorb it.
2. **Commit in logical slices; if the work turns out larger than the phase, STOP and return a
   proposed PR split with a merge order** — do not keep building. The scope-creep recipe of
   [`threading-model.md`](threading-model.md), specialized: the return is a split, not a bigger diff.
3. **Any sibling found outside scope is RETURNED as a finding to file — never fixed in place,
   never dropped.** "Out of scope for this PR" means *another phase*, not *not our problem*.
4. **When the phase touches tests — the three sub-rules and the mutation step**
   ([`tests-assert-behavior.md`](tests-assert-behavior.md)): assert the state change (specific
   values, counts, every field that must change and must not); pin diverging quantities
   deliberately unequal; **prove the teeth by changing ONE LINE of the implementation, watching
   RED, editing it back, and saying so in the return** — never delete, move, rename or copy over a
   file to force RED, no backup and no restore command; a restore from git is an INCIDENT to
   report, not a step. A test rewritten because it asserted the old broken behavior is part of
   the fix — name it in the return.
5. **When implementing an AC someone else wrote — read it adversarially.** The issue body's
   diagnosis is the trustworthy part; the AC is the part that has not been costed. If satisfying
   it would install a SECOND expression of a rule the system already expresses once, that is a
   **fork** — STOP and return it. If it names a column or dimension that does not exist, it is a
   decision phase, not a criterion. Real precedent: in a random sample of twenty audit-filed
   high-severity issues, zero diagnoses were fabricated but roughly half were over-ranked, and the
   forking risk sat almost entirely in the ACs.
6. **Before returning, run the adjacency check on YOUR OWN DIFF and return the block VERBATIM**
   ([`adjacency-check.md`](adjacency-check.md)) — outward (every fact the diff now states: where
   else is it stated?) and inward (every guard the diff relies on: can it fire here?). **A diff
   that touches any Markdown file carries a doc-corpus line** — the claim grepped across the
   tracked docs, sites and files counted, reconciled. Five PRs paid an average of four reviewer
   rounds for that line's absence.
7. **No AI-attribution trailer** on the commit or PR body.
8. **Stop after commit.** Commit locally, return branch + SHA; do NOT push, do NOT open a PR;
   never `git stash pop` / `drop` / `clear` — the stash is repo-global across worktrees
   ([`capacity-and-worktrees.md`](capacity-and-worktrees.md)).

**Fix-cycle briefs get one extra line:** *this finding may not be alone* — classify it against the
pattern inventory and sweep for siblings BEFORE fixing; the sweep may change the remedy. Real
precedent: a narrow "you introduced a drift" finding, swept, predated the PR and was wider; the
remedy changed from adding a column to correcting the contract.
