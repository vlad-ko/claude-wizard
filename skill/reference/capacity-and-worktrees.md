# Capacity and worktrees — the test-running budget, the gotchas, the clean slate

> Loaded on demand by the wizard SKILL. The always-on summary lives in the SKILL body
> ("Capacity: two independent limits"); this file holds the two independent limits, the
> core-derived budget and its fail-closed reading, the worktree gotchas, homeostasis, and the
> fresh-main recipe.

## Two independent limits

| Limit | Units | What it gates |
|---|---|---|
| **The open-PR band** | PRs per author in the review cycle | Whether to spawn a NEW candidate build ([`parallel-pipeline.md`](parallel-pipeline.md)) |
| **The test-running budget** | Concurrent agents that will run the suite | EVERY suite-running dispatch — builders, fix agents, `qa-engineer` runs |

They have different units, and raising the first never licenses raising the second. Real
precedent: the PR ceiling was legitimately raised and the agent count rode along with it, because
one number was being read as covering both. What made it look safe was per-agent test databases —
which isolate **schemas, not compute**: every database lives in one server process, every suite
runs in one app container, and both compete for one pool of host cores and memory.

**Non-test agents are nearly free and are NOT part of the budget.** Measured in one session:
test-running agents took 117–136 minutes each; docs, triage, filing and analysis agents took
3–16 minutes. Dispatch the second kind at full width regardless of the verdict — a HOLD is never a
licence to idle; it redirects fan-out to the cheap half. The budget is decided by the **brief**,
not the agent type: a "builder" whose phase is a config edit with no suite run consumes no slot; a
docs agent asked to verify a test does.

## The budget — core-derived, fail-closed

```text
concurrent test-running agents = max(1, min(floor(effective_cores / 2), 6))
effective_cores = min(host cores, container-VM cores)
```

- **Read both counts and take the smaller** (host: `sysctl -n hw.ncpu` / `nproc`; VM: your
  container runtime's reported CPU count), because the suite runs inside the VM and the host count
  can overstate what it gets. On an 8-core reference host the two happened to coincide — a
  coincidence of one machine's settings, not a guarantee. `floor` keeps it defined on odd cores;
  `max(1, …)` keeps it usable on small ones; the `6` cap binds only at 12+ cores, where memory and
  the single database server run out before cores do.
- **If either count cannot be read, FAIL CLOSED to 1.** An unmeasured host is not a fast host;
  substituting a remembered number is absence rendered as a value
  ([`absence-is-not-a-value.md`](absence-is-not-a-value.md)).
- **Why the shape:** at **9** concurrent suite runs on 8 cores the load average was **12**, the
  database server sat near 100% CPU, and each test process showed a few percent — the processes
  were blocked on the one shared server, so each added agent mostly added a waiter.

**The cost is trustworthiness, not latency.** Over-dispatch manufactures false signals shaped
exactly like real defects: the database container was OOM-killed and every sibling's result in
that window was untrustworthy; a per-test time limit fired mid-migration and every later test in
the class failed the same way; a dependency install hit its timeout and two builders lost the
ability to run RED before implementing. Each costs more agent time to disprove than the parallelism
bought. **A failure cluster during contention is not evidence about the diff** — route it through
`resource-manager`'s trust assessment before filing anything or briefing a fixer.

### Admit against agents DISPATCHED, not processes alive

A builder dispatched two minutes ago is still cloning or writing code — it holds a slot it has not
started using and is invisible to a process count. Admitting a second wave against a live count
books capacity the first wave will claim later, and the waves collide at test time. **The
orchestrator's own task list of dispatched suite-running agents is the admission register**; the
process count is a diagnostic that corroborates it. A persistent gap between the two means an agent
finished, crashed, or never reached testing — worth knowing either way.

### Queue the overflow; never kill a running builder

Put the over-budget task in the task list as a pending dispatch and release it when a running
agent lands. **Never kill a builder to free a slot**: its work is uncommitted by construction
(stop-after-commit), so a kill destroys hours and returns nothing. Termination is an orchestrator
decision on `resource-manager` evidence, and the bar is an unambiguous hang — a long-lived process
over a worktree whose dirty-file count is **static** across two samples while the server is
quiet — not a slow run. A static count under a saturated server is grinding, not death; a fresh
transcript timestamp is evidence of execution, never of progress — check the work product (a
commit, a push, a PR) instead.

### `resource-manager`'s verdict is a PRECONDITION

Before any test-running dispatch, and after a wave finishes, dispatch `resource-manager` for a
verdict with a free-slot count. **`GO` is the only verdict that permits a dispatch.** `HOLD`
(at budget), `HOLD-DEGRADED` (a measured threshold — memory, disk, an unhealthy container — blocks
even with free slots), `HOLD-RECLAIM-PROPOSED` (the only blocker is disk that orphaned test
schemas would return — it has NOT reclaimed anything; the user approves the proposed drop list,
someone runs it, then the verdict is re-measured) and `INCONCLUSIVE` (a probe did not return — an
unmeasured resource is never a free one) all block. It **measures, reports and proposes; it
mutates nothing** — every destructive remedy is a proposal the user approves. Real precedent: it
once dropped fourteen schemas as routine work and disclosed it afterwards; propose-not-perform is
the correction. Honest rung: an application check the orchestrator must remember to invoke;
nothing blocks a dispatch that ignores it.

## Worktree gotchas

Each worktree runs its own branch against one shared container stack. The traps below are the
ones that repeatedly cost multi-PR sessions.

1. **One git index per worktree — so one committer, or path-scoped commits.** Concurrent agents in
   the same worktree race the index. Either one agent commits, or each commits ONLY its own
   explicit paths (`git add <paths>`, never `-A`) under the non-overlapping file ownership of
   [`ensemble-dispatch.md`](ensemble-dispatch.md).
2. **`refs/stash` is repo-global, not per-worktree — never `git stash pop` / `drop` / `clear`.**
   Every worktree pushes onto and pops from the same stack; a bare `pop` restores whoever landed
   last, and the losing side sees its entry vanish with no error. Real precedent, ~9 concurrent
   builders: one agent's mutation-check `pop` took a sibling's five-file WIP, deleted seeder
   included. Use a **per-worktree shelf** — a script built on `git stash create` (a stash commit
   with no ref) plus the per-worktree `refs/worktree/*` namespace, so another worktree cannot even
   *name* your shelf; `restore` applies and KEEPS. For a pristine tree, add a second detached
   worktree. **A one-line mutation check needs no shelf at all** — edit the line, run, edit it
   back. A git hook cannot soundly block `stash pop` (a drop is usually a ref *update*, the reflog
   is truncated before the transaction, and `--autostash` breaks); an opt-in pre-tool-use deny on
   the three verbs is the structural rung.
3. **A dependency-directory symlink runs MAIN's code.** A worktree whose dependency directory is a
   symlink back to the primary checkout resolves the application base path to the primary — the
   suite loads main's classes, not the branch's. Install dependencies inside the worktree, or set
   the base-path override explicitly on every run; a per-worktree setup script that does both and
   then **smoke-tests its own postconditions** (the default connection resolves to this worktree's
   database, zero pending migrations, a page renders) is what turns "it exited 0" into "it is
   ready." A created-but-unmigrated database fails most of the suite on missing tables, and the
   failure reads as a regression in the diff.
4. **Per-worktree test database — and a per-worktree test ENV.** One isolated database per
   worktree, **copied** into a container-visible env file, never symlinked (a symlink resolves to a
   host path the container cannot see, so the override is silently lost). The test-lane env file
   is **generated from a tracked template**, not copied from a developer's untracked one: a copy
   spreads one laptop's state into every worktree, and a key that leaks in and happens to *match*
   the expected value passes for the wrong reason, invisibly.
5. **The stale-origin diff.** A worktree branched at task start shows large *false deletions* of
   files sibling merges added since. Before trusting a diff or pushing: `git fetch origin main`,
   check `git diff --stat origin/main`, rebase, then grep the resolved files for orphan conflict
   markers and duplicate import lines — `rebase --continue` does not lint them. Push the branch
   from `git branch --show-current`, never the worktree directory's basename.
6. **A container bind mount can serve a STALE or SIZE-CLAMPED copy of a file you just edited.**
   Measured: an edit that GROWS a file is served truncated to the size it had when the container
   started — whatever tool wrote it — and one copy was torn, matching neither version's hash. This
   corrupts the mutation loop in **both** directions: a truncation mid-statement is a bogus RED (a
   parse error); a truncation past the mutated line is a bogus GREEN. **Before trusting any
   container-side result on a file you just edited, compare the checksum host vs container** and
   grep the mutated line container-side; poll until they agree. A `sleep` is not a fix; `touch`
   and in-place rewrites do not clear it; a container restart does. A container-to-host copy
   writes THROUGH to the host. Repairing a mount-corrupted file is not restoring a file you removed.
7. **Never delete-and-recreate a file to force a test outcome.** The tell is intent: if your plan
   has the file existing again afterwards, do not remove it. A deleted file is the *weaker*
   mutation (it proves "nothing works without this file", pinning nothing), and a hand-rolled
   backup is what a parallel agent's scratchpad cleanup deleted mid-cycle in a real session.
   Needing to restore from git is an incident to report, not a step; if agreed, name the source
   (`git restore --source=HEAD -- <file>` — the path-only form restores from the index). Method:
   [`tests-assert-behavior.md`](tests-assert-behavior.md).
8. **Subagents idle if allowed to wait.** Brief a code-writing subagent to run through
   `git commit` and return immediately; the orchestrator treats **worktree state as the source of
   truth** (commits ahead + clean tree = done), not the task notification, which can be missed.

## Clean slate — homeostasis

**Every task and every cohort ends on a CLEAN SLATE, and the primary checkout IS the slate.** Work
happens in worktrees; the primary is the baseline every session and every subagent starts from,
so it is left as a fresh clone of main would be. A dirty primary is drift the next session
inherits: stale-main reads that report merged work as absent, rebases against the wrong base,
a leftover test database that drifted from main's migrations and produced false-RED tests chased
as a regression. Real precedent: one repository was found carrying 379 worktrees (59 GB), 306 of
them for merged PRs; on another day 371 merged local branches, 42 orphan test schemas with no
worktree, and stray files at the repo root, all invisible until someone looked.

The seven checks, run at the end of every task and before any handoff:

1. The primary is on main, fast-forwarded to `origin/main` — a failed fetch is INCONCLUSIVE,
   never "fresh".
2. No modified tracked files.
3. No untracked paths (scratch belongs in the session scratchpad).
4. Every worktree whose PR has MERGED is removed — **classified by change TYPE first, never
   removed blind**: removable only when it has no tracked change, no untracked path, and every
   ignored path is on the regenerable allowlist (dependency directory, build output, generated env
   files, caches). Real edits, gutted shells and non-regenerable ignored files are KEPT and
   SURFACED by name.
5. Every local branch merged into main is deleted with `-d` (which refuses an unmerged branch),
   never `-D`.
6. No debris directory git has forgotten under the worktree root.
7. No orphan test schema whose worktree is gone.

A check script exits non-zero on ANY violation; an apply mode performs only the safe subset —
unforced worktree removal (re-classified immediately before removal, since another agent may have
locked or edited it in the gap), prune, `-d` on merged branches, dropping orphan schemas — and
never touches a modified file, never forces, never acts on a read that failed. The user reviews
the report before apply runs. Honest rung: a check script a session can decline to run; the
structural rung is an opt-in stop hook.

## Working from a fresh main

Fast-forward the local main ref before ANY critical decision, code-audit read, subagent dispatch,
or system-level filing — a stale checkout makes merged work look ABSENT. Two cases, and the wrong
one silently does the wrong thing:

```bash
# On main:
git -C <repo-root> fetch origin main && git -C <repo-root> merge --ff-only origin/main
# On a feature branch (fast-forwards the local main ref without switching):
git -C <repo-root> fetch origin main:main
```

Put `-C` on BOTH calls, or the second runs in the shell's cwd. Never `merge --ff-only origin/main`
from a feature branch — it merges main INTO the branch and succeeds silently; the `main:main`
refspec fails on main because git refuses to fetch into the checked-out branch.

**"Already implemented / already GREEN / no RED to write" is a stale-main signal FIRST.** The
issue is usually the phantom, not the code. The authoritative check is the synced main timeline
(`git log --oneline origin/main`, or the symbol existing on `origin/main`); a merged-PR title
search is a secondary heuristic whose empty result proves nothing. Worktree-isolated subagents
branch off the latest `origin/main` and are immune; only the primary checkout drifts. Real
precedent: a 60-commit-stale main produced a phantom "missing config" issue and a redundant PR
for work a merged PR had already delivered.
