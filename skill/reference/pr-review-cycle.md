# PR & AI-review cycle

> Loaded on demand by the wizard SKILL. The always-on summary lives in the SKILL body ("PR & Review Cycle"); this file holds the per-commit loop, the four finding surfaces and the one
> canonical detector, the clearing mechanism per surface, the fix-routing tree, the SHA-bound
> merge-ready gate, quiescence, and the recurring traps.

In delegated mode this phase runs in the **orchestrator**, starting at push + PR-open. It is
non-negotiable: every feature branch goes through the review cycle before it is called ready to
merge, and **the user merges** — you declare, you never `pr merge`.

## The per-commit monitoring loop

```
PUSH commit → RECORD finding IDs per reviewer → WAIT for the reviewers on this SHA →
LIST finding IDs again → for every NEW finding: FIX (dispatch a fix-subagent) or REPLY (false
positive) → RESOLVE the thread → PUSH the fix → REPEAT for every commit, including fix commits
```

- **EVERY finding gets a response** — a fix commit or a false-positive reply. A reviewer
  *question* is a finding. A nitpick is a finding. A low-severity note is a finding. Unreplied
  is unmergeable regardless of reviewer or severity.
- A fix commit that draws new findings — those ALSO need responses. Five or six fix cycles per PR
  is normal for an exhaustive reviewer profile, not a sign you broke something.
- Detect new findings by **ID per reviewer**, never by count or by position — the host moves
  comments between commits when it resolves diff positions.
- NEVER declare ready while any status is pending. "Running" is not "passing."

## The FOUR finding surfaces

A one-surface sweep misses findings. Every actionable finding lands on one of:

1. **Inline review threads** — anchored to a diff line. Unresolved + current blocks.
2. **Review bodies** — a review's top-level body, including **nested collapsible sections** some
   bots fold nitpicks, refactor suggestions, duplicates and outside-diff-range findings into. Open
   the full body; an empty preview is not an empty finding. A body that *declares* N findings but
   yields fewer when parsed is a mismatch — inspect by hand, never trust the under-count.
3. **Issue-level PR comments** — a standalone summary comment with actionable rows, unchecked
   pre-merge boxes, or warning callouts.
4. **A check-run based reviewer's output** — its conclusion. `success` is clean; `neutral` /
   `action_required` means it posted findings, which block through surfaces 1–3 on their own
   evidence; the bare conclusion is non-blocking and cleared with a post-dating acknowledgment. An
   ABSENT check-run never blocks — but only acknowledge the absence once it is past the bound your
   suite gate waits out.

## ONE canonical detector — never hand-roll a finding query

The operator's pre-merge audit and the CI findings gate run the **same** detector over the same
four surfaces, so the two cannot diverge. **Never hand-roll host-API / `jq` / grep finding
queries** — that drift structurally enabled the same recurrence three times: an audit regex keyed
on a reviewer's display name instead of its login silently zeroed the count; a body-only nested
finding sat unreplied because a thread-only audit could not see it; a blockquoted outside-diff
finding was under-counted to zero. Each time the query existed and was run; each time it differed
from the gate's. If your project has no such detector, build ONE and make both call it.

The detector emits each finding as a stable `(kind, key)` — a thread on its thread id, an
issue-level finding on its comment timestamp, a body finding on its review id. An unprovable
identity is a null key and **INCONCLUSIVE**, never a fresh zero-attempt finding. That identity is
what lets the ledger count fixers per finding and rule one STUCK (`parallel-pipeline.md`).

## Addressing a finding is ONE step: reply AND resolve

A reply alone does not close the loop — a replied-but-unresolved thread still renders as an open
conversation, so a genuinely clean PR reads as full of unaddressed problems. Precedent: the user
flagged a PR where every finding had a reply and every thread was still open. The merge-ready bar
is: every addressed finding's thread is resolved. Leave a thread open only while its finding is
genuinely still in progress.

**The clearing mechanism differs by surface:**

| Surface | Cleared by |
|---|---|
| Inline thread | An **INLINE reply in that thread** (`in_reply_to` the finding comment) + resolve the thread. A PR-level comment does NOT clear an inline finding. |
| Review-body finding (no thread) | A **post-dating, non-bot PR-level comment** quoting the finding and stating the fix or the reason. |
| Issue-level comment | A post-dating acknowledgment reply. |
| Check-run conclusion | A post-dating acknowledgment once its findings on surfaces 1–3 are cleared. |

- An `isOutdated` thread (the hunk moved under it) still resolves by the same mutation; outdated
  does not exempt it.
- A bot that retracts its own finding after a fix and resolves the thread itself satisfies the
  gate — no self-reply needed.
- Reply formats: `Fixed in <SHA>. <what changed and why>` / `Not applicable: <why>`.
- A reply does NOT re-trigger CI. Where you need a fresh run or a stuck reviewer poked (queued with
  zero check-runs for more than ~5 minutes), push an empty retrigger commit — third-party
  check-suites cannot be re-requested through the host API.

## Separate the PREMISE from the REMEDY

A reviewer's **premise** (a real problem exists) is often right while its suggested **fix** is
wrong for this repo's tooling, platform or data — applying the remedy verbatim ships a regression
while accepting a legitimate finding. Split the two questions, and before applying a proposed
change run the cheapest reality check: does that command exist on the dev host AND in CI? does the
cited constant, line or option exist? does the regex still match the real target? Fix the *correct*
way and say so in the reply; if the premise itself is a misread, reply `Not applicable:` with the
evidence. Precedent: seven misfires in one session, each a plausible premise paired with a remedy
that would have broken a shell tool, the local platform, or pinned a line that did not exist.

**Sibling-audit before pushing a reviewer fix.** When a reviewer flags ONE instance of a pattern,
grep the touched subsystem and fix the in-scope siblings in the same commit (file the rest). A
reviewer re-reviews every push and will otherwise walk the siblings one per commit, each a fresh
unanswered finding in a user-visible window. Precedent: fourteen commits dropping one column.

## Fix routing in delegated mode

**The orchestrator authors NO repo code.** The only pure-orchestrator outcome is **(1) false
positive** — reply + resolve, no code. **EVERY change to repo code, tests or config** — a fix, an
assertion tweak, a constant swap, a file removal — is **(2) a dispatched fix-subagent, per
finding, never batched**. The moment the orchestrator opens an editor it stops orchestrating and
serializes work N threads could do in parallel; a subagent round-trip is cheaper than the lost
parallelism. When a PR carries several findings, **fan out by layer** — backend →
`backend-expert`, view layer → `frontend-expert`, test coverage → `qa-engineer`,
design/adversarial → `architect` — under the non-overlapping file-ownership contract (each commits
ONLY its own files by explicit path). Never brief one agent to "fix everything." Within (2) the
**liveness probe** picks a warm `SendMessage` or spawn-fresh into the existing worktree; the
bands and the `isolation: "worktree"` caveat are in `threading-model.md`.

## The merge-ready gate — SHA-bound, declared once

A PR is merge-ready ONLY when ALL hold, at one named HEAD SHA:

- `mergeable` is `MERGEABLE` — `CONFLICTING` disqualifies; `UNKNOWN` is "not computed yet",
  re-query, never declare on it. Resolving conflicts is part of the cycle, not optional cleanup.
- **Every required check reports success — the set is READ from branch protection, never recited
  from a doc**, because a hand-curated list is right until protection changes and silently wrong
  after. An empty read is a refusal, not "nothing is required." Read each as the KIND it is: a
  commit status by its `state`, a check-run by its `conclusion`; reduce check-run rows to the newest
  per name first — the rollup does not deduplicate them.
- **Every state lands in a named arm; there is no `else` that could become a pass.** `SUCCESS` is
  the only PASS. `PENDING` / `EXPECTED` are WAIT. `FAILURE` / `ERROR` / `CANCELLED` / `TIMED_OUT`
  are FAIL. A null, a missing row or an errored read is INCONCLUSIVE and BLOCKS — never "not
  required, proceed." Precedent: an audit reading the wrong field reported a passed suite as "never
  reported" for three hours; the dangerous reading of the same null is the opposite one.
- **Pin the read to ONE commit.** Read `headRefOid` in the SAME call as the check rollup, compare
  to the SHA the detector used, and on any difference **restart the audit**.
- The canonical detector reports all four finding surfaces clean.
- The full test suite passed on this SHA.
- **New-line coverage — a self-audit, not a gate:** if your PR path has no coverage tooling, walk
  your own diff and either add the test in this PR or document the gap in the PR body. A merge-ready
  criterion whose evidence is *absent* must FAIL or be removed, never silently pass — precedent: a
  dormant coverage check configured to report success on no upload kept "passing" for months after
  its upload step had been removed.
- The **reviewer-quiescence window** has elapsed since the latest push, with a clean
  post-quiescence re-audit.

Then post a **structured pre-merge audit comment on the PR** — HEAD SHA in the heading, each
criterion with its concrete extracted value (counts, run ids, timestamps), ASCII markers, no
placeholders — and declare merge-ready to the user in one sentence referencing that comment's URL.
The comment is where merge-ready *lives* for a user who merges from the host UI; if chat and
comment disagree the comment wins. If any criterion fails, do not post; restart. Precedent: two PRs
in one session were declared merge-ready in chat while findings sat unreplied — the queries were
run, but a "clean" verdict that never had to survive contact with extracted counts did not.

**SHA-bound:** any new commit after the declaration — including an auto-merge from main when a
sibling lands — invalidates it. Reviewers re-evaluate the whole file on every push and can post a
new P1 on a commit whose only diff is a clean main-merge. Name the SHA in the declaration; if HEAD
moves, the cycle restarts and a fresh audit comment is posted (never edit the old one in place).

## Reviewer quiescence — why a status check is not the gate

Comment-only reviewers post no completion signal: "no findings yet" is indistinguishable from
"still working" except by waiting. So the gate is **the latest review post-dates the latest push +
a quiescence window covering the empirical late-arrival envelope (~12 minutes on a busy repo) + a
clean re-audit** — not "all checks green." An early verdict from one reviewer does not shorten the
wait for the others. Take the commit timestamp from the host API in UTC, never from local `git log`
with a timezone offset, or the string comparison lies. The window is a MINIMUM after a push, not a
cadence: if the push is already older than the window, audit NOW — never re-pause. And there is no
benefit polling a reviewer before ~5 minutes; it has not started.

**Communication discipline in the window:** until the gate clears, "merge-ready" and every soft
cousin — "merge-ready path", "essentially ready", "ready pending CI", "just waiting on the last
reviewer" — is forbidden in user-facing text; the user reads them as a verdict and may merge on
it. Precedent: "back on the merge-ready path" thirty seconds after a fix commit, and three findings
landed inside the next four minutes. The honest shape: "Reviewers + CI green at `<SHA>`; quiescence
expires at `<T>`; will declare then if the re-audit is clean."

## The suite may run only after reviewers settle

If your CI holds the suite until reviewers finish, a local regression surfaces at the END of the
cycle — so **run affected tests locally before every commit**; local is the only immediate feedback
a fix gets. Two corollaries: polling the suite during the reviewer window buys nothing (it is
blocked, by design), and **open findings mean the suite may never have run** — a PR with a red
findings gate has not been tested by CI at all, whatever the reviewer signals say. The green CI
checkmark is the LAST gate, not an afterthought. Precedent: a PR declared merge-ready on reviewer
signals while the suite was still running; the suite then failed on a view-compile collision no
narrow local filter had exercised.

## CI-failure reproduction

When CI fails, read the failed-job log (the rollup shows pass/fail; the log shows the error),
reproduce with the SAME filter the failing job used — not a narrower one — fix the root cause, add a
regression test that catches the failure mode without a full CI run, and re-run locally before
pushing. Don't fix the symptom.

**Rule out a transient infra flake first.** A red suite on an otherwise clean PR with no
reproducible local failure is often a registry pull timeout or a missing shard artifact, not a
regression. Re-run the failed run and confirm before pursuing a code fix; only a failure that
survives the re-run or reproduces locally is real. Route `ERROR` exactly like `FAILURE` — it is
what a status publisher reports when the publisher itself broke, so it is if anything MORE likely
to be infra.

## Recurring traps

- **The status rollup is a summary, not the source of truth.** It collapses statuses to the newest
  per context but NOT check-runs, so a superseded failure can block its own replacement success.
  When declaring merge-ready, also sweep the latest run per workflow on HEAD.
- **A green check-run from a non-blocking tool means only "the tool finished without erroring."**
  The comment body or log it leaves is the source of truth; when they disagree, the log wins.
- **A sibling merge invalidates every open branch's base.** It can flip a clean PR to
  `CONFLICTING` with no new commit, or auto-update the branch and reopen its review cycle.
  Re-check `mergeable` and HEAD on every open PR after every merge.
- **The bot edits findings in place** — retracting or rewriting after a fix lands. Capture finding
  data for any record *before* you push the fix.
- **An empty finding preview is not an empty finding** — fetch the full body when the markers
  suggest content.
- **Reviewers disagree.** Act on the *union* of valid findings and reply to the rest as false
  positives; never dismiss one reviewer's finding because another was silent on it.
