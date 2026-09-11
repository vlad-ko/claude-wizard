# Parallel pipeline — the open-PR cohort moves in unison

> Loaded on demand by the wizard SKILL. The always-on summary lives in the SKILL body
> ("The Open-PR Cohort Moves in Unison"); this file holds the event-driven wake model, the ledger idle test, the
> two-cost check-in, the wakeup handler, findings-before-builds, build-ahead, the depth band,
> the collision guard, compaction recovery, the worktree-isolation pattern and conflict hygiene.

Wait windows in the PR cycle — a reviewer pass, the CI suite, the quiescence window — are
**work-time, not pause-time**. The orchestrator spends them running multiple in-flight
workstreams. It is the single coordinator; workers are siloed by worktree. **Driving open PRs to
merge-ready ranks AHEAD of new building** — a PR you pushed and walked away from is unfinished
work, never something you return to when reminded.

## Wake on events, never on a clock

The events already exist, and the sweep rides turns you are already taking — it adds ZERO wakes:

| Trigger | Action |
|---|---|
| **Every push** you just made | Sweep the whole lane NOW, in that turn |
| **Every subagent return** (task-notification) | Sweep NOW |
| **Every user turn** | Sweep NOW |
| **Before answering any question about PR state** | Sweep FIRST — the highest-consequence change, **the user merging**, emits no signal and invalidates every open branch's base |
| ONE named external state nothing will notify you about (a specific CI run, a reviewer quiescence window) | ONE `ScheduleWakeup` sized to **that** state, expiring when it resolves — never re-armed to keep the session warm |
| Anything else — "work is in flight but nothing specific is pending" | Schedule nothing |

**There is no recurring tick and no fallback heartbeat.** The old cadence-ceiling rule is gone,
and the reason is cost: a tick fired past the prompt-cache TTL pays a full cache write on the whole
resident context, so a "cheap" replacement tick is not cheap — at ~20 wakes an hour it was millions
of cache-read tokens per hour whether or not anything needed doing. A "just in case" wakeup is the
cron rebuilt under a one-shot primitive. **The one exemption is the `resource-manager` tick** —
host state (a hung builder, a filling volume, memory walking toward an OOM) emits no event, so that
clock stays recurring while a test-running agent is in flight (`capacity-and-worktrees.md`).

**What this gives up, stated plainly:** a session neither running an agent nor being talked to
holds no wake signal, and detection latency there is unbounded. The answer is a discipline, not a
timer — **finish the sweep in the turn you are already in**. Precedent: a wakeup chain one turn
forgot to re-arm died silently and left findings unaddressed for over an hour, until the user asked.

## The idle test is the LEDGER, not the event queue

**The absence of an event is not the absence of work.** The diagnosis that recurs — "I run on
events; findings land 5–15 minutes after a push and nothing notifies me; so I move to the next
thing that IS an event" — is true in every clause and wrong in its conclusion, because the lane's
state is **durable**: `pr-checkin` writes a per-PR ledger on every sweep, readable on any turn for
the cost of a file read. You are idle only when BOTH halves are empty:

1. **The per-PR ledger** shows no open PR needing attention.
2. **The development cohort** is empty — nothing in flight and no same-author candidate the
   selection rule would pick, proven by the queries you ran, not asserted.

**A stale, absent or unreadable ledger is INCONCLUSIVE, never idle** (`absence-is-not-a-value.md`).
The directions are not symmetric: a non-empty record *proves* there is work; a clean record cannot
speak for findings posted after it was written, so "none" closes only on a live re-derivation. No
freshness threshold may be invented — a threshold is the tick again. Precedent: with the triggers
already documented, an orchestrator sat with open PRs carrying red findings and offered the
events-only diagnosis; the user rejected it as an excuse, three times in one session.

## Two agents, two costs — never hand-roll either

- **`pr-checkin`** runs on every trigger above. Cheap — a mechanical-tier model over mechanical
  inputs (HEAD SHA, check states, thread counts, timestamps) — answering ONE question: has anything
  changed since the last record, and is any PR unattended? It writes the ledger either way and
  returns `HOLD` / `ESCALATE` / `INCONCLUSIVE`. **Never `HOLD` on a probe you could not read.**
- **`pr-manager`** runs only on an escalation. It re-derives each PR's condition in its OWN context
  (billed once, not re-read on every later call of yours) and returns a compact verdict plus one
  **routed brief per finding** for you to dispatch. It owns what a live read cannot reconstruct:
  detection-to-routing latency, and whether a finding is slow or **STUCK** (briefs routed
  repeatedly, nothing landing).

A hand-rolled `gh` loop in the orchestrator loses both silently: the ledger, and the context spent
re-reading every thread of every PR on every turn.

## The wakeup handler — run in order on every trigger

1. **Broken-main emergency check.** If the project's main branch is broken (a tracked broken-main
   issue is open), that overrides everything until main is green again.
2. **Sweep every spawned worktree** — the worktree is the source of truth, because a
   task-notification can be buffered, compacted away, or land between turns:
   - ahead ≥ 1 + clean → push now (after the stale-origin check below). Inventory is not in-flight.
   - dirty + no commits → the worker crashed; dispatch an **adopt-and-verify** worker INTO that
     worktree. UNLESS it was an infra/watchdog stall mid-coherent-work — then discard the worktree
     and re-dispatch fresh with the stalled agent's diagnosis baked in **as a hypothesis**. Confirm
     the death via the notification or a `SendMessage` probe; a stale output mtime is not a signal.
   - clean + no commits → still working, or returned without committing (a design-block, drift or
     environment return — act on the type).
3. **Open-PR audit — findings before builds** (next section). Dispatch `pr-checkin`; on
   `ESCALATE`, dispatch `pr-manager`; dispatch a fixer for every routed brief in the SAME turn.
4. **Count cycle-depth** for the session author: open PRs minus the merge-ready ones.
5. **Decide on depth.** Below the band with no candidate-prep worker running → spawn the next
   candidate THIS turn, after the capacity gate. At the cap → hand the user the merge list, no
   spawn. Never re-dispatch onto a PR that already has a fixer in flight.
6. **Cross-pollinate** a fixed finding's code-shape lesson to any held branch sharing the pattern —
   only fixed findings with merged precedent, never speculative ones.
7. **Post the outcome** — merge-ready PRs by SHA, what was dispatched, what was queued. "PR opened"
   is never an outcome.

**A wake ACTS; it does not report.** Posting "PR N has three unresolved threads" and leaving it for
a next wake that may never come is the failure mode wearing a wake's clothes.

## Findings before builds — the wake ORDER

Within step 3, in this order, and nothing reorders it:

1. **Sweep the whole lane** — every open PR, not the one in front of you.
2. **Dispatch a fixer for every eligible finding-bearing PR** in the same turn. Eligible excludes
   exactly two cases: a finding that already has a fixer in flight, and a finding or PR ruled
   **STUCK** — which **escalates to the user instead of drawing another brief**. "Not yet fixed" is
   never an exclusion.
3. **Only then consider new work.**

**Reviewers post 5–15 minutes AFTER a push**, so the push-time sweep fires at the one moment the
lane still looks clean. Which makes **opening a PR the alarm clock for the OLDER cohort, never the
sweep's subject**: the PR you just opened cannot carry anything yet; the ones opened fifteen
minutes ago do, and you are guaranteed awake. **A push STARTS a cycle.** Precedent: four PRs sat at
a red findings gate while new builds were dispatched — "why aren't you driving them to
merge-ready?" — and the shape repeated three more times the next session, after the ordering was
written down. The honest diagnosis: opening a PR feels like completion, and new work is more
interesting than clearing findings. Both are wrong — an unaddressed finding is unfinished work the
user can see and you cannot, and it blocks the merge that frees capacity for the build.

## All-merge-ready is a step, not an exit — BUILD AHEAD

A merge-ready PR is parked on a human merge: it consumes no reviewer attention and **no test
capacity**. So a fully merge-ready lane is *maximum* free capacity, not a finished run. In that
turn: post the merge list for the user, run the capacity gate (`resource-manager` is a
precondition of every test-running dispatch), take the next candidates ranked by harm, and dispatch
up to the smaller of the free-slot count and the room left under the band. A lane whose PRs are all
**escalated** has no room — escalated PRs still count in cycle-depth, and the correct act is the
decision they wait on. Precedent: the old loop posted the merge list and stopped, and nothing
started the next cohort until a human asked — the idle failure arriving through the exit.

**Build-ahead for a same-file cohort:** when N ≥ 3 branches all append to one shared registry or
config file, build them all in parallel while context is fresh, brief each to append at the END of
the file, and **defer opening their PRs** — open one, wait for its merge, rebase the next (one
keep-both union), open it. Opening all N at once only adds O(N²) re-conflict churn; the merges
serialize on the shared file regardless. Built-but-unopened branches do not count toward the band.

## Pipeline-depth band

Keep **8–10 open PRs per session author in the review cycle** — strive toward the top, hard max at
the top. The comparand is **cycle-depth** (open PRs minus merge-ready ones), read from
`pr-manager`'s classification, never the raw `gh pr list --author <login>` total: eight parked
merge-ready PRs are a cycle-depth of zero and the strongest top-up signal there is. The band gates
NEW candidate spawns only — a fixer on an already-open PR adds no depth and is never held by it, or
the pipeline deadlocks exactly when it is most stuck. The band is a **review-attention** budget;
concurrent test-running agents are a separate **hardware** budget (`capacity-and-worktrees.md`).
Raising one never licenses raising the other — precedent: a legitimately raised PR ceiling dragged
the agent count up with it and the cohort OOM-killed the shared test database, manufacturing
failures shaped exactly like real defects.

The top is bounded by reviewer rate limits (a "rate limited" note means retrigger next cycle, not
block). Stay below it only for a shared-file cascade cluster, one architecturally-coupled issue
spanning ordered PRs, or an empty same-author candidate pool — proven by the assignee AND author
queries you surface, never asserted.

## Idle is forbidden — a block gates only its own track

A pending user decision or a manual merge blocks ONLY the track that depends on it. Ask "what here
depends on the blocked thing, and what doesn't?" and dispatch everything that doesn't — a
multi-hour block should show N other tracks building, never a lone spinner. Workers are always
dispatched with `run_in_background: true`; a foreground `Agent` call blocks the orchestrator and is
the mechanical root of "why is everything serial." A two-option ask that differs only in
risk-mitigation, not in what ships, is the same violation as asking whether to find work: pick the
safer option and dispatch.

## Notify on block — never silent-wait

The moment the run gates on something **only the user can do** — a decision, a merge — fire a
`PushNotification` stating exactly what is needed ("PR N merge-ready at `<SHA>` — your merge").
A silent poll makes the thread look busy while the user has no idea anything waits on them.
Precedent: a ~2-hour dead gap idling on a decision with zero user-facing signal.

## Dispatch-collision guard

Before dispatching a worker for a feature or phase, confirm the work is not already in flight:
search the host for an existing PR AND check uncommitted worktrees (`git worktree list`,
`git branch --list <target>`, `git -C <path> status --short`). A finished-but-uncommitted build
lost across compaction looks exactly like "nothing started"; re-dispatching produces a duplicate
that races the original. **Adopt-and-verify** a stalled build — a fresh worker into the existing
worktree, never `isolation: "worktree"` — rather than rebuild. This is why per-PR task metadata
records the worktree's absolute path.

## Context-compaction recovery

If the orchestrator's context compacts mid-flight, the monitoring state survives in persistent
tasks (`TaskList`) and the per-PR ledger on disk. Reconstruct from those plus the session author's
open-PR list, then run the wakeup handler from step 1. Tasks and the ledger persist; conversation
memory and inline tables do not.

## Subagent worktree-isolation pattern

`isolation: "worktree"` gives each new-feature worker its own worktree on a fresh branch off
`origin/main`, so edits never collide with the orchestrator or sibling workers. A worker sees only
its brief plus `CLAUDE.md`, so brief it like a colleague who walked in cold:

- **First action:** the per-worktree setup step that gives the worktree its OWN dependency
  directory, runtime dirs, built assets and an **isolated test database** — a symlinked dependency
  directory runs MAIN's code, and a shared test database name deadlocks the cohort
  (`capacity-and-worktrees.md`).
- **What to build + acceptance criteria** (pasted from the issue), **files NOT to touch** (in-flight
  siblings), the project's production-path expectations.
- **Test execution against the worktree's own code** — the full affected test *class*, never a
  single method, so autoload-time validation catches cross-branch drift. Never mirror files into the
  main checkout and revert by name: that raced under parallel agents and wiped other agents' edits.
- **Stop after commit — do NOT push, do NOT open the PR.** Return branch, SHA, files touched, test
  results, open questions, a suggested PR title + body.
- The five failure-recipe lines and the no-AI-attribution line (`threading-model.md`).

**Crash recovery:** a task-notification carrying an API error after a long run usually leaves the
work in the worktree. Substantive modifications with zero commits ahead means salvage — dispatched
to an adopt-and-verify worker in place, never authored by the orchestrator. **After a structural
refactor, smoke-test before pushing:** a worker's self-report is necessary, not sufficient —
spot-check that new anchor links target real `#` headings and that split snippets run in a fresh
shell.

## Stale-origin diff trap

A worker that branched from `origin/main` at task start can, by completion, show false
*deletions* of files that sibling merges added during its task. Before every push: `git fetch
origin main` in the worktree, `git diff --stat origin/main`, and if the diff deletes files the task
never touched, `git rebase origin/main`, resolve, run the hygiene checks below, and re-verify the
diff is pure additions.

## Conflict-resolution hygiene

- **Orphan markers** — `git rebase --continue` commits leftover `<<<<<<<` / `=======` /
  `>>>>>>>` lines without complaint. Grep for them after every resolution AND after the rebase
  reports success; amend if any survive. Never push a live marker.
- **Duplicate statements** — keep-both-blocks keeps both copies of an import or registration both
  halves contained. Grep for duplicates and run your language's syntax check on every resolved
  file. Precedent: three sibling PRs shipped duplicate imports from one rebase — three force-push
  cycles for what one post-resolve grep would have caught.
- **`--ours` / `--theirs` are INVERTED during a rebase** vs. a merge: during a rebase `--ours` is
  the branch you are rebasing *onto* (main) and `--theirs` the incoming commit. For a
  canonical-vs-stub conflict during a rebase, `--ours` keeps main's canonical implementation;
  `--theirs` keeps the stub — the exact failure being prevented. After either flag, open the file
  and confirm the contents are what you intended.
- **A sibling merge can flip any open PR to CONFLICTING** with no new commit to it. Re-check
  `mergeable` on every open PR after every merge; resolving a conflict outranks spawning new work.

## Clean slate

Every task and every cohort ends with the primary checkout clean on fresh main — no worktree of
a merged PR, no merged branch, real edits in a dirty worktree surfaced rather than removed blind.
The check, the safe-apply subset and the worktree gotchas (one git index per worktree, the
repo-global stash, the dependency-directory symlink trap) are in `capacity-and-worktrees.md`.
