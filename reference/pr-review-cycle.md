# PR & AI-review cycle

> Loaded on demand by the wizard SKILL. The always-on summary lives in the SKILL body ("PR & AI
> Code Review Cycle"); this file holds the per-commit loop, the merge-ready gate, and the
> recurring traps.

In delegated mode this phase runs in the **orchestrator**, starting at push + PR-open. It is
non-negotiable: every feature branch goes through the review cycle before it is considered ready
to merge.

## The per-commit monitoring loop

```
PUSH commit → WAIT for the review bot / CI status on this SHA → READ every finding →
FIX valid ones (dispatch a fix-subagent) or REPLY to false positives → resolve the thread →
PUSH the fix → REPEAT for every commit
```

Rules:

- After EVERY push, wait for the status checks on that SHA to complete.
- **EVERY finding MUST have a response** — a fix commit or a false-positive reply. Never skip a
  finding, even a low-severity one. A reviewer *question* counts as a finding and needs a reply.
- A fix commit that introduces new findings — those ALSO require responses.
- NEVER declare the PR ready while a status is pending.
- Continue until the review bot returns a clean status and every thread is resolved.

## Audit all three finding surfaces

Review bots post findings on more than one surface, and a one-surface sweep misses some. Check all
of:

1. **Inline review comments** — anchored to a diff line.
2. **Review bodies** — a review can carry findings in its top-level body (and some bots nest
   collapsible "nitpick" sections inside the body markdown — open the full body, don't trust an
   empty preview).
3. **Issue-level summary comments** — a standalone PR comment, often a summary that still wants an
   acknowledgment reply.

Some findings ("outside the diff range") create no resolvable thread — add an acknowledgment reply
so the audit doesn't flag them as un-addressed.

## Separate the PREMISE from the REMEDY

When a reviewer flags something, its **premise** (a real problem exists) is often right while its
suggested **fix** is wrong for this repo's actual tooling/platform/data — applying the remedy
verbatim ships a regression while accepting a legitimate finding. Treat every suggested remedy as
a hypothesis: run the cheapest reality check (does that command exist on this OS and in CI? does
the cited constant/line/option actually exist? does the suggested regex still match the real
target?) before applying. Then fix the *correct* way and say so in the reply.

## The merge-ready gate

A PR is merge-ready ONLY when ALL hold:

- `mergeable` (no conflicts).
- Every blocking check is green.
- Every reviewer finding (any surface, any severity, including questions) is replied to AND its
  thread resolved.
- The full test suite passed on the current SHA.
- Patch-coverage is at the project's target (read the coverage bot's PR-comment body, not just the
  check-run conclusion).
- A reviewer-**quiescence window** has elapsed since the latest push (so comment-only reviewers
  with no pollable signal have had time to post), with a clean post-quiescence re-audit.

Then post a structured pre-merge audit comment and declare merge-ready referencing it — **the user
merges manually**. Never auto-merge. Until the gate clears, the word "merge-ready" and its soft
cousins are forbidden in user-facing text.

## Reviewer quiescence — why a status check is not the gate

Status check-runs are unreliable as the readiness signal: they can be absent (a comment-only
reviewer posts no status), stuck, or frozen on a stale SHA. So the gate is **review-post-dates-
the-latest-push + a quiescence window + a clean re-audit**, not "all checks green." A pending
check on the current HEAD must never be neglected, but a *missing* one is not proof of readiness.

Different bots post on different cadences (one may post within a few minutes of push; a slower one
several minutes later). The quiescence window exists to let the slow ones land before you audit.

## CI-failure reproduction

When CI fails, reproduce the failure locally before guessing at a fix — read the full failure
output, identify the root cause, fix that, and re-run the affected tests locally before pushing.
Don't fix the symptom.

## Recurring traps

- **Status rollup is not the source of truth.** Query the individual checks + the finding threads,
  not just the aggregate "checks passing" rollup.
- **A sibling merge can flip your PR to CONFLICTING.** When any PR in the cohort merges, re-check
  the mergeable state of all the others.
- **The review bot edits findings in place** — if you capture finding data for any record, capture
  it *before* you push the fix, because a bot may retract or rewrite the finding after the fix
  lands.
- **An empty finding preview is not an empty finding** — fetch the full body when the preview is
  blank but the markers suggest content.
