# Parallel pipeline — don't idle

> Loaded on demand by the wizard SKILL. The always-on summary lives in the SKILL body
> ("Parallel Pipeline"); this file holds the wakeup algorithm, the depth band, and the
> conflict-resolution hygiene.

Wait windows in the PR cycle — a reviewer pass, the CI suite, the quiescence window — are
**work-time, not pause-time**. The orchestrator spends them productively by running multiple
in-flight workstreams. It is the single coordinator; workers are siloed by worktree.

## The wakeup-handler algorithm

Run this on **every wakeup, every user interaction, and every subagent return**, in order:

1. **Broken-main emergency check.** If the project's main branch is broken (a tracked
   broken-main issue is open), that overrides everything until main is green again.
2. **Sweep every spawned worktree** — the worktree is the source of truth:
   - ahead ≥ 1 + clean → push (after a rebase / stale-origin diff check).
   - dirty + no commits → the worker crashed mid-work; take over — UNLESS the failure was an
     infra/watchdog stall mid-correct-work, in which case discard the half-done worktree and
     re-dispatch fresh with the stalled agent's diagnosis baked in as a hypothesis.
   - clean + no commits → still working, or returned without committing.
3. **Audit every open PR for new findings** (one batched sweep across ALL PRs, not one loop per
   PR).
4. **Count the session author's pushed-and-open PRs.**
5. **If depth is below the band and no candidate-prep worker is running → spawn the next
   candidate THIS turn** (don't defer).
6. **Cross-pollinate** fixed code-shape lessons to held branches (apply a fixed finding's fix
   preemptively to a held branch that shares the pattern).
7. **Schedule the next wakeup** at a short cadence ceiling while any worker or open PR is in
   flight.

## Pipeline-depth band

Keep a band of **open PRs per author** (a small handful — strive toward the top of the band,
with a hard max). At the cap, drive a merge first; do not spawn. The depth query is `pr list
--author <session-login> --state open`.

The band is bounded in practice by two real constraints (neither a hard merge gate, both degrade
at scale): **(a) worktree resource contention** — each worker needs its own isolated test
environment; a shared resource (e.g. a hard-coded test database name) collides and deadlocks the
cohort, so every worker brief MUST override the shared resource per-worktree; **(b) reviewer rate
limits** — more simultaneously-open PRs means the review bot increasingly reports "rate limited";
treat that as a retrigger-next-cycle note, not a block. Stay below the cap only for a shared-file
cascade cluster, a single architecturally-coupled issue spanning ordered PRs, or an empty
candidate pool. Otherwise fill toward the top.

## Idle is forbidden

The orchestrator is never idle while independent work exists. The only exceptions: (a) a broken
main (overrides everything), or (b) a genuinely empty same-author candidate pool. A pending owner
decision or a manual merge **blocks only the track that depends on it** — before scheduling any
idle wakeup, ask "what here depends on the blocked thing, and what doesn't?" and dispatch
everything that doesn't.

Workers are always dispatched to run **in the background** — a foreground dispatch blocks the
orchestrator and is the mechanical root of "why is everything serial."

## Notify on block — never silent-wait

The moment the run gates on something **only the user can do** — an owner decision, or a manual
merge/action — fire a **user-facing notification** stating exactly what's needed ("waiting on
your Option-A decision", "PR #N merge-ready — your merge"). Do NOT lapse into a silent poll loop
as the *only* signal; that spends the user's time without their knowledge (they can't act on a
block they can't see). Keep a long-interval heartbeat only as a safety net behind the
notification.

## Dispatch-collision guard

Before dispatching a worker for a feature/phase, confirm the work isn't already in flight: check
for an existing PR (search the host) AND check *uncommitted worktrees* (`git worktree list`,
`git branch --list <target>`). A finished-but-uncommitted build lost across context compaction
looks exactly like "nothing started" — re-dispatching produces a duplicate that races the
original. When you find a stalled build, **adopt-and-verify** it (a fresh worker into the existing
worktree to run the suite + commit), do not rebuild from scratch. This is why per-PR task state
records the worktree absolute path.

## Context-compaction recovery

If the orchestrator's context compacts mid-flight, the in-flight monitoring state survives in
persistent tasks. On a fresh session, reconstruct by enumerating the tracked tasks and
cross-referencing the open-PR list for the session author. Resume the monitoring loop from there.
Tasks persist; conversation memory and inline tables do not.

## Conflict-resolution hygiene

When rebasing a held branch or resolving a sibling-merge conflict:

- **Orphan markers** — grep the diff for leftover `<<<<<<<` / `=======` / `>>>>>>>` before
  committing a resolution.
- **Duplicate statements** — a "keep both blocks" resolution can duplicate an import or a
  declaration; grep for duplicates after resolving.
- **`--ours` / `--theirs` are INVERTED during a rebase** vs. a merge. During a rebase, `--ours`
  is the branch you're rebasing *onto* (the target/main), `--theirs` is the incoming branch.
  After resolving with `--ours`, audit the downstream callers/tests the incoming branch added —
  they may now reference code the `--ours` resolution dropped.

## Stale-origin diff trap

A worker that branched from `origin/main` at task start can, by completion, show false deletions
of files that sibling merges added during its task. Always `git fetch` and check the diff against
*fresh* origin/main before push; rebase if the base moved.
