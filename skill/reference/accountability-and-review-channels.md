# The accountability lead, a second review channel, and rules with teeth

> Loaded on demand by the wizard SKILL. The always-on summary lives in the SKILL body
> ("Threading Model"); this file holds the four questions, why the lead reports to the user,
> the background review channel, and the authoring rule for observable-shape guards.

All three rules below were earned by measured failures in one session; each states its precedent
so it is not read past.

## The accountability lead — a second lead that audits the first

### The failure it closes

The orchestrator's characteristic failure is **not going too fast**. It is **reporting instead of
clearing** — narrating dispatch counts while PRs sit red.

That failure is **invisible from inside the orchestrator**, because from there every turn looks
like progress: an agent was dispatched, a reply was posted, a finding was filed. Nothing in the
loop contradicts it. Real precedent: the user intervened twice in one session — *"we are again
sitting with open PRs with red X's"* and *"it seems we are still filing more issues than
solving"*. Both were correct, both were mechanically checkable, and in both cases the
orchestrator was mid-report with an unswept lane. **A loop whose only accountability check is the
user does not have one.**

### When to spawn it

Any run with **3+ concurrent PRs**. Dispatch `accountability-lead` at cohort start and again at
each milestone (a merge, a phase completing, a status report). It is a non-test agent, so it never
competes for the test-running budget ([`capacity-and-worktrees.md`](capacity-and-worktrees.md)).

### The four questions

Each is a **query, not a judgement** — the agent reports the query beside the answer so the finding
is a citable artifact, not an opinion.

1. **Is any open PR red with no fixer dispatched against it?** A red check with a fixer working is
   the loop functioning; a red check with nothing in flight is the failure. The auditor cannot see
   the dispatch list, so it asks plainly rather than speculating.
2. **Is the main verb "opened" / "dispatched" rather than "merge-ready"?** The observable proxy is
   merge-ready count versus open count across two runs. If open grows while merge-ready is flat,
   that is the tell — the pipeline is filling, not draining.
3. **Does any PR body claim "filed" against an issue that does not resolve?** Real precedent:
   *"findings filed, not fixed here"* went into **five** PR bodies where nothing had been filed,
   and two more cited no issue at all. A claim of filing is verified against the tracker, never
   taken from the body.
4. **Is the findings-per-PR-merged multiplier above 1 and unremarked?** Measured that day: 4.3.
   Filing faster than merging is not necessarily wrong, but it is never something the orchestrator
   gets to leave unsaid.

### Why it reports to the USER

Routing the audit through the loop being audited defeats the purpose. Its value is being outside
it. The orchestrator **relays the verdict verbatim** — never summarised into something gentler —
and fires a user-facing notification (`PushNotification`) on any verdict that is not ON-TRACK, so
the user can act on a stall they would otherwise not see.

### Boundary and provenance

It never builds, fixes, files, pushes or merges. It is not `pr-manager` (which drives PRs forward)
and not `backlog-manager` (which curates the tracker): it audits the **orchestrator's behaviour**
against the exit condition. The pattern adopts the audit half of the two-lead arrangement in which
each lead can restart the other; the restart half needs a supervisor outside both and is not
implemented here.

## A second review channel — not subject to a third party's quota

Claude Code's `/code-review` at `high` effort or above runs as a **background agent** and does not
take over the session. **Dispatch it as a second review channel at PR-open**, rather than waiting
only on the review bots. It costs no test-running slot and no orchestrator context.

**Why it matters concretely.** Real precedent: a review bot was rate-limited to one included
review per hour against eleven open PRs. Seven carried a green `pass` check it had **never run** —
its own footer read *"review rate limited"*. A check that is green because a third party's quota
was exhausted is worse than a red one, because the merge gate sails through it. A local channel
is not subject to that quota; it does not replace the bots, it keeps reviewer coverage from going
to zero when their quota does.

**Always state the coverage gap in the merge-ready audit** when a reviewer did not actually run.
A rate-limited `pass` is *not reviewed*, and counting it as coverage is the failure
([`pr-review-cycle.md`](pr-review-cycle.md)).

## Rules with teeth — write guards against observable SHAPE, never motive

Several rules in this skill honestly record their rung as **guidance**: the ban on deleting a
file to force a test outcome, the ban on `git stash pop`, the "user merges" gate. Each names a
structural rung that exists — a pre-tool-use deny hook, or a classifier-read deny list in user
settings that project settings cannot override — but is opt-in per machine.

When you author such a rule for a mechanical guard, **write it against observable shape, never
motive.** A critique pass rejected a first draft whose `rm` rule triggered on *"in order to force
a test outcome"*: the trigger is motive, which a classifier can rarely establish from a command
line — `rm tests/FooTest` looks identical whether it is cleanup or cheating. Write the shape
instead: *bare `rm` or `mv` of a git-tracked file* (leaving `git rm` / `git mv` open, so a
reviewed removal still proceeds). The same pass caught three more defects worth generalising:

- **An empty environment section starves every rule.** A guard that references a shared
  container stack or multiple worktrees is unusable if the classifier does not know those facts
  exist. State the environment first.
- **A deny with no matching allow generates friction.** Declaring the stack shared primes the
  defaults to flag the ordinary test loop. Carve-outs belong in an explicit allow, not buried in
  a deny.
- **"Never" in a soft rule does not mean never.** Soft rules clear when the user names the
  specifics. Either make it hard, or state what clears it — otherwise the classifier improvises
  the bar.
- **Enumerate the escape paths.** A `pr merge` ban leaks through the raw API merge endpoint, a
  local `git merge` plus push, and an auto-merge flag. A rule that closes one spelling of a
  capability has not closed the capability ([`remove-the-mechanism.md`](remove-the-mechanism.md)).

**Treat an empty critique as inconclusive, not clean.** After the rewrite the critique tool
returned *"no critique was generated"* twice. That is not evidence the rules are correct — it is
an unreadable result, and the refusal posture of
[`absence-is-not-a-value.md`](absence-is-not-a-value.md) applies unchanged.

**Scope.** Such rules encode one operator's machine — a shared container stack, a worktree count,
an authenticated cloud — so they are user-machine configuration, deliberately not committed. What
is committed is the pattern and the critique discipline, so it is reproducible rather than
folklore.
