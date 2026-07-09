# Threading model — orchestrator and worker, and why the boundary is `git commit`

> Loaded on demand by the wizard SKILL. The threading-model overview and the fix-routing
> decision tree live in the SKILL body ("Threading Model"); this file holds the rationale and
> the failure recipes.

The wizard describes the full feature lifecycle. It runs in one of two modes; the boundary
between them is **who runs the PR cycle**.

**Direct mode (single thread).** A single thread runs the whole skill end-to-end — no
orchestrator/worker split, no agent dispatch. It owns every phase including the PR monitoring
loop. No special handoff.

**Delegated mode (orchestrator + worker).** The work is dispatched by the **orchestrator** (the
conversation thread the user talks to) to a **worker subagent**. Responsibility splits at the
`git commit`: the subagent commits locally, the orchestrator does everything from `git push`
onward.

## Why the boundary is `git commit`, not `git push` or "PR opened"

The commit line is the **two-phase-commit point** between local work (fully reversible at zero
cost) and external commitments (CI fires, reviewers get notified, the host records check-runs
against the SHA). Splitting responsibility there buys five concrete things:

1. **Verify the diff before exposing it.** The orchestrator runs a sanity check on the
   subagent's branch before push. A real failure mode: a worker branches from `origin/main` at
   task start; sibling PRs merge during its task; by completion `git diff --stat origin/main HEAD`
   shows large *false* deletions of files those siblings added. The orchestrator catches this
   pre-push and rebases onto fresh main. If the subagent had pushed, the PR would open with a
   confusing "deletes N files" diff. The same trap applies to orphan conflict markers and
   accidental staging.
2. **Enforce backpressure at the moment of external visibility.** The per-author pipeline-depth
   band is enforced at the *spawn* of a new worker, but the *visible* PR count only changes when
   a PR opens. If workers auto-pushed, N background subagents could finish within seconds of each
   other and race to push — the orchestrator couldn't stagger them or hold one back.
3. **Compose the PR title/body with cross-cut context.** The worker knows what it built. The
   orchestrator knows what other PRs are open, what conventional-commit prefix the squash-merge
   versioning policy needs, which sibling-PR findings to reference. A worker's PR description is
   inevitably narrower.
4. **Clean failure recovery.** If a worker crashes mid-task and nothing was pushed, the
   orchestrator inspects `git status`, finds the work sitting uncommitted, audits it, and commits
   from a clean state. If the subagent had pushed before crashing, recovery means a PR with
   partial work, a branch in unknown state, possible CI on incomplete code, and reviewer comments
   to clean up.
5. **Single monitoring owner.** "The user merges manually" requires ONE entity that knows the
   full state of all in-flight PRs, so it declares merge-ready exactly once per PR. If subagents
   owned monitoring, you'd get N parallel polling loops, N races on declaring merge-ready, and N
   copies of context burning on host-API chatter instead of code.

### "Shouldn't the subagent at least open the PR?"

By the time the PR-open step runs, the branch is already pushed (CI is firing), the title must
use a conventional-commit prefix (versioning-dependent), and the body needs cross-PR context.
Splitting commit/push at one line and push/PR-open at a second adds coordination overhead with no
benefit. The orchestrator is already involved at push time, so it opens the PR in the same turn.

### Fix-cycle subagents on already-open PRs

The same boundary holds. A fix-cycle subagent commits the fix locally; the orchestrator pushes.
The orchestrator coordinates push + reply + thread-resolve as a unit, so the findings-resolution
gate always sees a fresh push together with its replies — never a push with no replies that would
fail the audit.

## What the worker does vs. the orchestrator

- **Worker:** runs design-through-self-review (implementation + commit), then returns its result
  to the orchestrator with branch name + final commit SHA. **Does NOT push, does NOT open the
  PR.** It does NOT run the per-commit monitoring loop, the finding-reply cycle, or the
  merge-ready audit. Its entire context window goes to implementation, not polling chatter.
- **Orchestrator:** pushes the branch, opens the PR (title + summary composed from the worker's
  return plus its own cross-cut context), and runs the PR cycle for every PR. It tracks per-PR
  state in **persistent task state** (one task per monitored PR: HEAD SHA, last-poll timestamp,
  replied-finding IDs, the worker's worktree path + branch). Tasks survive context compaction;
  inline conversation tables do not — that is the load-bearing reason to use persistent tasks.

## The fix-routing decision tree (orchestrator does NOT author repo code in delegated mode)

In delegated/parallel-pipeline mode the orchestrator is the **integrator** and does NOT author
repo code. The only pure-orchestrator finding outcome is **(1) false positive** — reply + resolve
the thread, no code change. EVERY change to repo code/tests/config — fixes, finding-remediation,
an assertion tweak, a file removal, a constant swap — is a **(2) dispatched fix-subagent**, on
each finding, not batched. The moment the orchestrator opens an editor on repo code it stops
orchestrating and serializes work a thread could do in parallel; a subagent round-trip is cheaper
than the lost parallelism.

For a (2) real fix, run a **liveness probe** first: if the original worker is recently active
(roughly within a few minutes), continue it with a message; otherwise spawn a fresh fix-subagent
*into the existing worktree* (not a fresh worktree). On any continuation error, fall through to
spawn-fresh immediately — do not loop-retry.

**Fan out by concern to specialists.** When a PR carries multiple findings, route each to the
agent whose layer it lives in — backend logic → `backend-expert`, view layer → `frontend-expert`,
test coverage → `qa-engineer`, design/adversarial → `architect`. Do NOT brief one agent to "fix
everything." When multiple fix-agents share one worktree, give each a NON-OVERLAPPING file set and
have each commit ONLY its own files (`git add <explicit paths>`, never `git add -A`).

## Failure recipes (worker return → orchestrator response)

Five non-happy-path returns recur often enough to need named recipes. Bake the matching brief
lines into every dispatch — a worker only sees its brief plus the auto-loaded `CLAUDE.md`, never
this file.

| Pattern | Trigger | Worker action | Orchestrator response |
|---|---|---|---|
| **fix-and-return** | Verification reveals a typo / missing fixture / minor mismatch in the worker's *own* work. | Fix inline, re-run the affected tests, commit (or amend if unpushed), return per the standard contract. | Push + PR cycle as normal. No special handling. |
| **scope-creep** | The worker finds the bug is broader than briefed (e.g. three sibling files share the gap). | Commit the **briefed** fix only — do NOT chase the siblings. Return with a `scope note:` listing each sibling locator. | Push the briefed fix; file a follow-up issue listing the siblings; do NOT re-spawn to chase them in the same PR (scope discipline preserves reviewability). |
| **design-block** | The briefed task contradicts an existing constraint/invariant or depends on unmerged work. | Do NOT commit. Return with `blocker: <constraint>` + one or more `suggested resolution:` lines. Leave the worktree clean. | Escalate to the user with the blocker + suggestions, OR re-brief with the chosen resolution baked in. |
| **environment failure** | A required tool is unavailable mid-phase (container down, auth expired, read-only volume). | Do NOT commit partial work. Return with `environment: <issue>` + `last-good-step: <resume point>`. | Fix the env, then resume (continue the warm worker, or spawn fresh with `last-good-step` quoted verbatim). |
| **drift** | The worker's first read of a briefed file shows it changed since the brief was written (a sibling PR merged). | Pause immediately. Do NOT commit. Return with `drift: <file> changed at <SHA>` + a one-line summary. | Decide whether the brief still applies; re-brief with the current state, or close the task and update the backlog issue. |

**Subagents do NOT inherit SKILL-level conventions.** A worker sees only its dispatch brief +
the auto-loaded `CLAUDE.md` — never this SKILL or its references. So any behavior you need a
worker to follow — the test-execution recipe, an anti-pattern warning, a tool choice, these
failure-mode lines, the no-AI-attribution rule — MUST live in the BRIEF. And when you supersede a
script or convention, **remove the old artifact** so a worker's grep can't surface stale guidance
and follow it.
