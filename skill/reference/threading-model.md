# Threading model — orchestrator and worker, and why the boundary is `git commit`

> Loaded on demand by the wizard SKILL. The threading-model overview and the fix-routing
> decision tree live in the SKILL body ("Threading Model"); this file holds the rationale, the
> per-PR task state, the liveness probe, the failure recipes and the brief-template lines.

The wizard describes the full feature lifecycle. It runs in one of two modes; the boundary
between them is **who runs the PR cycle**.

**Direct mode (single thread).** A single thread runs the whole skill end-to-end — no
orchestrator/worker split, no agent dispatch. It owns every phase including the PR monitoring
loop. No special handoff.

**Delegated mode (orchestrator + worker).** The work is dispatched by the **orchestrator** (the
conversation thread the user talks to) to a **worker subagent** via the `Agent` tool.
Responsibility splits at the `git commit`: the subagent commits locally, the orchestrator does
everything from `git push` onward.

**Picking your mode:** if you were invoked via the `Agent` tool with a brief like "implement X,
commit, return," you are a worker — stop at commit and return branch + SHA. If you are the thread
the user is talking to, or you are invoking `Agent` yourself, you are the orchestrator and own
everything from push onward.

## Why the boundary is `git commit`, not `git push` or "PR opened"

The commit line is the **two-phase-commit point** between local work (fully reversible at zero
cost) and external commitments (CI fires, reviewers get notified, the host records check-runs
against the SHA). Splitting responsibility there buys five concrete things:

1. **Verify the diff before exposing it.** A worker that branched from `origin/main` at task
   start can, after sibling merges, show large *false* deletions of files those siblings added.
   The orchestrator catches this pre-push and rebases onto fresh main; had the worker pushed, the
   PR would open with a confusing "deletes N files" diff. Same trap for orphan conflict markers
   and accidental staging (`parallel-pipeline.md`).
2. **Enforce backpressure at the moment of external visibility.** The depth band is enforced at
   *spawn*, but the visible PR count changes only at PR-open. If workers auto-pushed, N background
   subagents could finish within seconds of each other and race to push.
3. **Compose the PR title/body with cross-cut context.** The worker knows what it built. The
   orchestrator knows what else is open, which conventional-commit prefix the versioning policy
   needs, which sibling findings to reference, and what the adjacency-check block must say
   (`adjacency-check.md`).
4. **Clean failure recovery.** If a worker crashes with nothing pushed, the work sits uncommitted
   in its worktree for an adopt-and-verify worker to audit and commit. Had it pushed first,
   recovery means a PR with partial work, CI on incomplete code, and reviewer comments to clean up.
5. **Single monitoring owner.** "The user merges manually" needs ONE entity that knows every
   in-flight PR's state and declares merge-ready exactly once per PR, SHA-bound — not N polling
   loops, N races, and N copies of context burning on host-API chatter.

### "Shouldn't the subagent at least open the PR?"

By the time the PR-open step runs, the branch is already pushed (CI is firing), the title must
use a conventional-commit prefix (versioning-dependent), and the body needs cross-PR context.
Splitting commit/push at one line and push/PR-open at a second adds coordination overhead with no
benefit. The orchestrator is already involved at push time, so it opens the PR in the same turn.

### Fix-cycle subagents on already-open PRs

The same boundary holds. A fix-cycle subagent commits the fix locally; the orchestrator pushes.
The orchestrator coordinates push + reply + thread-resolve as a unit, so the findings gate always
sees a fresh push together with its replies — never a push with no replies that would fail the
audit.

## What the worker does vs. the orchestrator

- **Worker:** runs design-through-self-review (implementation + commit), then returns branch
  name + final commit SHA + files touched + test results + open questions. **Does NOT push, does
  NOT open the PR.** It does NOT run the per-commit monitoring loop, the finding-reply cycle, or the
  merge-ready audit. Its entire context window goes to implementation, not polling chatter. The
  `Agent` tool's completion semantic is the handoff — one result message when the task finishes.
- **Orchestrator:** pushes the branch, opens the PR (title + body composed from the worker's
  return plus its own cross-cut context), and runs the PR cycle for every PR
  (`pr-review-cycle.md`) — riding the event-driven sweep, never a clock (`parallel-pipeline.md`).
  It declares merge-ready when the gate clears and fires a `PushNotification` so the user is
  pulled back rather than left to discover it.

### Per-PR task state — persistent, not an inline table

Track each monitored PR with `TaskCreate` / `TaskUpdate`, one task per PR. Tasks survive context
compaction; conversation tables do not — that is the load-bearing reason. Metadata per task:

| Field | Why it is there |
|---|---|
| HEAD SHA | merge-ready is SHA-bound; a moved HEAD restarts the cycle |
| last-poll timestamp | what the last sweep saw, so a later finding on the same SHA is still detected |
| replied-finding IDs, per reviewer | new-finding detection is by ID, never by count |
| subagent ID | warm-resume target for `SendMessage` |
| worktree absolute path + branch | a finished-but-uncommitted build is never lost across compaction (the dispatch-collision guard) |
| `agent_last_seen_at` | the last time the worker successfully returned — initial completion or a `SendMessage` reply; gates the liveness probe below |
| quiescence start | the latest push's UTC timestamp, the floor the merge-ready window is measured from |
| fixer dispatch count, per finding key and per PR | what lets a finding be ruled STUCK instead of re-dispatched forever |

On a fresh session after compaction, reconstruct from `TaskList` + the session author's open-PR
list + the check-in ledger, then resume the sweep.

## The fix-routing decision tree (the orchestrator authors NO repo code)

In delegated mode the orchestrator is the **integrator**. The only pure-orchestrator finding
outcome is **(1) false positive** — reply + resolve the thread, no code change. **EVERY change to
repo code, tests or config** — a fix, a finding remediation, a one-line assertion edit, a file
removal, a constant swap, an import tidy — is **(2) a dispatched fix-subagent**, per finding, not
batched.

**The "provably trivial" carve-out is RETIRED.** There is no "small enough for the orchestrator"
path for repo code: provability by inspection tells the *dispatched* worker how cheap the fix is;
it never licenses the orchestrator to apply it. If a fix touches a tracked repo file, it is (2),
full stop. The reason is architectural, not capability: the moment the orchestrator opens an editor
it stops orchestrating and serializes work N threads could do in parallel. Precedent: the
orchestrator did inline test edits and a file removal itself, and the user flagged that it slowed
the whole pipeline. The orchestrator keeps only the plumbing it always owned: `git push` from a
returned worktree, PR/issue creation, thread reply and resolve, a keep-both union at rebase time,
task and memory writes, `ScheduleWakeup` / `PushNotification`.

**Fan out by concern to specialists.** When a PR carries multiple findings, route each to the
agent whose layer it lives in — backend logic → `backend-expert`, view layer → `frontend-expert`,
test coverage → `qa-engineer`, design/adversarial → `architect`. Do NOT brief one agent to "fix
everything" — folding separated findings into one kitchen-sink fixer re-serializes what the gate
just parallelized. When several fix-agents share one worktree they race the one git index, so give
each a **non-overlapping file set** and have each commit ONLY its own files (`git add <explicit
paths>`, never `git add -A`); when files cannot be partitioned, sequence them in the shared
worktree, or give each concern its own worktree and reconcile (`ensemble-dispatch.md`).

### The liveness probe — run first, every time

For a (2) fix, read the task's `agent_last_seen_at` and route:

| Age | Route |
|---|---|
| ≲ 5 min | **(2a) `SendMessage`** to the warm worker — lowest cost when it works. The runtime reclaims idle sessions after a few minutes; on ANY error (agent not found, timeout, malformed reply) fall through to (2b) immediately, never loop-retry. Update `agent_last_seen_at` only on a *successful* reply. |
| 5–10 min | Judgment call; **default to (2b) when unsure** — a fresh worker is cheap next to misrouted state. |
| ≳ 10 min | **(2b) spawn-fresh** into the existing worktree — the default. |

**The `isolation: "worktree"` caveat:** that parameter always creates a *fresh* worktree off
`origin/main` — wrong for a fix on an existing branch. For (2b), omit it and put in the brief: the
existing worktree's absolute path, the PR branch, "cd there and `git pull --rebase origin
<branch>` first", the per-worktree test contract, and the ONE finding — PR, finding URL + body,
file:line — "address this finding, commit locally, return; do NOT push." Fresh feature-prep workers
DO use `isolation: "worktree"`; the distinction is whether the work attaches to an existing branch.

## Failure recipes (worker return → orchestrator response)

Five non-happy-path returns recur often enough to need named recipes — the worker's action on
recognising the mode, and the orchestrator's response on reading the return.

| Pattern | Trigger | Worker action | Orchestrator response |
|---|---|---|---|
| **fix-and-return** | Verification reveals a typo / missing fixture / minor mismatch in the worker's *own* work (not pre-existing). | Fix inline, re-run the affected test class, commit (or amend if unpushed), return per the standard contract. | Push + PR cycle as normal. No special handling. |
| **scope-creep** | The worker finds the bug is broader than briefed (three sibling files share the gap). | Commit the **briefed** fix only — do NOT chase the siblings. Return with a `scope note: also affects <file>:<line>` line per sibling. | Push the briefed fix; file a follow-up issue listing the siblings (the complete inventory lands in the ISSUE, `phased-decomposition.md`); do NOT re-spawn to chase them in the same PR. |
| **design-block** | The briefed task contradicts an existing constraint or invariant, would undo a deliberate prior fix, or depends on unmerged work. | Do NOT commit. Return with `blocker: <constraint>` + one or more `suggested resolution:` lines. Leave the worktree clean. | Escalate to the user with the blocker + suggestions, OR re-brief (warm `SendMessage`, else spawn fresh) with the chosen resolution baked in. |
| **environment failure** | A required tool is unavailable mid-phase (test container down, host-CLI auth expired, read-only volume). | Do NOT commit partial work. Return with `environment: <issue>` + `last-good-step: <resume point>` (e.g. `implementation-complete-uncommitted`, `affected-tests-passing`). | Fix the env, then resume — continue the warm worker, or spawn fresh with `last-good-step` quoted verbatim into the brief. |
| **drift** | The worker's first read of a briefed file shows it changed since the brief was written (a sibling PR merged, a hotfix landed). | Pause immediately. Do NOT commit. Return with `drift: <file> changed at <SHA>` + a one-line summary of the change. | Decide whether the brief still applies; re-brief with the current state, or close the task and update the backlog issue. |

### Mandatory brief-template lines

Append these near the end of EVERY delegated-mode `Agent` brief. A brief that omits any of them is
incomplete: the worker falls back to its own judgment on that pattern, which produces inconsistent
handoffs.

> If you hit a **fix-and-return** case (verification reveals a typo / missing fixture / minor
> mismatch in *your own* work), fix it inline, re-run the affected test class, commit (or amend
> if not pushed), and return per the standard contract.
> If you hit a **scope-creep** finding (the bug is broader than briefed), commit the briefed fix
> only and list each sibling as a `scope note:` in your result.
> If you hit a **design-block** (the briefed task contradicts an existing constraint), do NOT
> commit; return with `blocker:` and `suggested resolution:` lines.
> If you hit an **environment failure** (test container down, host-CLI auth expired), do NOT
> commit; return with `environment:` and `last-good-step:`.
> If you hit **drift** (a file you need changed since the brief was written), pause and return
> with `drift: <file> changed at <SHA>`.
> Run the affected test *class* in THIS worktree's own environment; never mirror files into the
> main checkout.
> Your commit message MUST NOT carry any AI-attribution trailer; the harness default appends one
> — strip it before `git commit`.
> Otherwise commit and return branch + SHA — do NOT push, the orchestrator pushes.

Precedent for the attribution line: a PR shipped a `Co-Authored-By` trailer because the brief did
not restate the project rule and the tool default re-asserted itself.

## Subagents do NOT inherit SKILL-level conventions

A worker dispatched via `Agent` gets its instructions from exactly two sources: the **dispatch
brief** and the auto-loaded **`CLAUDE.md`** (plus any `.claude/rules/` file a path it touches
loads). It does NOT load the wizard SKILL or anything under `reference/`. So any behavior you need
a worker to follow — the test-execution recipe, an anti-pattern warning, a tool choice, the
failure-mode lines above — MUST live in the BRIEF or in `CLAUDE.md`. A correct rule that lives only
in a SKILL reference is invisible to the agent that needs it.

**And when you supersede a script or convention, REMOVE the old artifact so a grep cannot surface
it.** Precedent: after a new worktree-setup helper landed and the SKILL references were updated,
the next batch of workers STILL used the retired mirror-and-revert dance — they never read the
SKILL; they grepped the repo, found the *old* helper with its stale header comment, and followed
that. A stale on-disk reference outweighs an updated SKILL the worker never reads.

## The accountability lead

On any run with 3+ concurrent PRs, spawn a second lead whose ONLY job is to audit the first. The
failure it catches — **reporting instead of clearing** — is invisible from inside the loop, because
every turn looks like progress. It answers four mechanically checkable questions and reports **to
the user, not the orchestrator** — relay its block VERBATIM and `PushNotification` any verdict that
is not ON TRACK. Precedent: the user intervened twice in one session on failures that were
mechanically checkable. The four questions and the second review channel:
`accountability-and-review-channels.md`.
