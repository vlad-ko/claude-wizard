# Ensemble dispatch — the gate-routed, orchestrator-mediated sequence

> Loaded on demand by the wizard SKILL. The always-on summary lives in the SKILL body
> ("Agent-Ensemble Dispatch"); this file holds the ordered dispatch sequence, the mediated
> hand-off constraint, the initial-build fan-out and its file-ownership contract, the
> verification loop, and the cost/isolation guardrails.

The ensemble is an **orchestrator-workers** topology with a **prompt-chaining** spine. The
orchestrator is the wizard's main thread; the workers are the roster subagents. Two properties
govern everything below: **the complexity gate fires first** — no agent is spawned, not even the
first lens, until [`complexity-gate.md`](complexity-gate.md) has returned a band — and **every
hand-off is orchestrator-mediated**.

## The ordered sequence

```text
  briefed unit of work
        │
        ▼
  [0]  Complexity gate → the BAND (how many AGENTS, never how many PRs)
        │     Band 1 → one subagent, STOP (except 0.5) · Band 2 → default smaller
        │     Capacity gate beside it: resource-manager GO before any
        │     TEST-RUNNING dispatch (capacity-and-worktrees.md)
        ▼
  [0.5] Decompose and FILE the phases — EVERY band; dispatch ONE phase, ONE OWNER
        │     Band 1/2 build the phase with the smaller set and stop; Band 3:
        ▼
  [1]  PARALLEL: persona lenses ∥ doc-librarian  → orchestrator MERGES
        ▼
  [2]  architect (read-only): design + RED spec + CONTRACT → orchestrator SLICES
        ▼
  [3-5] PARALLEL off the contract, by FILE ownership:
       backend-expert ∥ frontend-expert ∥ qa-engineer (role a: coverage)
        ▼
  [6]  INDEPENDENT verification (generator ≠ evaluator), as a LOOP:
       qa-engineer (role b) · lenses re-dispatched · doc-librarian
        ▼
  [7]  PR cycle (pr-review-cycle.md) driven by pr-checkin / pr-manager
```

Every arrow is orchestrator-mediated: an agent returns ONE result; the orchestrator reads it and
bakes the relevant slice into the next agent's brief.

### Step 0 — the gate, and the capacity gate beside it

Take the band the gate returns; do not re-derive it here. Band 1 takes the single-subagent path
and the rest of this file does not apply — **except step 0.5, which runs at every band** because
it governs how many PRs the work ships as, not how many agents build it. The complexity gate
answers *how many agents does this work WARRANT*; `resource-manager`'s GO/HOLD answers *how many
can this host RUN right now* — a separate axis from both the band and the open-PR depth, and a
precondition of every test-running dispatch ([`capacity-and-worktrees.md`](capacity-and-worktrees.md)).

### Step 0.5 — decompose, file, then dispatch one phase to one owner

The method — phase shapes, slicing rules, ledger forms, the brief contract — is
[`phased-decomposition.md`](phased-decomposition.md). This step owns only the **routing**:

- **Who produces the plan.** A **genuine design fork** (a concurrency invariant, a lifecycle
  transition, findings whose grouping is itself a design question) → the `architect`, whose design
  and RED spec already imply the delivery order. Real precedent: dispatched for a design, the
  architect returned a six-PR split with per-PR risk and a must-not-batch flag on the riskiest,
  unprompted and correct. A **mechanical multi-site sweep** → the orchestrator decomposes directly
  from the sweep output; do not pay an architect spawn to re-derive a list you already hold.
- **Who files it: `issue-maintainer`.** Filing makes the phases *trackable state* rather than
  prose in the orchestrator's context — **the phase ledger IS the acceptance-criteria ledger.**
  File the COMPLETE inventory, not just the phases about to be built.
- **Who builds each phase: ONE phase, ONE OWNER — not one agent.** One brief, one worktree, one
  PR, one ledger entry, one accountable specialist routed by the phase's layer. The owner MAY fan
  out inside the phase when coupling is genuine; fan-out members contribute files and get no
  branch, PR or ledger entry. The branch and the merge boundary stay with the orchestrator
  ([`threading-model.md`](threading-model.md)).
- **Hybrid routing runs per phase** — each phase's triage manifest is small.

### Step 1 — parallel requirements hardening

The persona lenses (instances of [`domain-user-lens.template.md`](domain-user-lens.template.md))
and the `doc-librarian` run concurrently on the same input — the *sectioning* pattern. Each lens
returns a structured requirements-gap report (the permutations, edge cases and AC gaps
single-surface framing misses, plus its feature-parity and cross-actor-leak probes); the librarian
returns a **doc plan** (what the build must add or update, which orphans or stale cross-links sit
near the change). All are read-only. The orchestrator merges the reports into a **hardened AC set**
plus the doc plan — the architect's brief.

### Step 2 — architect: design, RED spec, contract

The `architect` maps the subsystem, enumerates invariants, runs the concurrency analysis for any
shared-state or lifecycle work, settles the design, authors the **RED failing-test spec** encoding
the hardened AC set, and writes the **data contract** — every view-data key, its type, range and
default — that both sides of the build code against. It writes no production code. The RED spec is
the compounding-error containment seam: every builder's output is checked against a failing test
the architect specified, not against the builder's own reading of the brief.

### Steps 3-5 — builders by file-domain, in parallel with qa coverage

Route the build to specialists **by the domain of the files each slice touches**, each briefed
with the design, its RED-spec slice, the contract keys its layer produces or consumes, and its
doc-plan items. Each materializes its RED spec into a failing test first, then writes the minimal
GREEN code. **RED is local discipline; a merged PR is always green** — test and implementation
land in the same PR.

**`qa-engineer` has TWO roles — do not conflate them.** **(a)** Initial-build coverage authoring:
concurrently with the builders, it authors test coverage for its owned test files **off the
architect's contract** — it does not wait on built code. **(b)** Post-GREEN verification (step 6):
a separate, later pass over the assembled result. Role (a) is a member of the concurrent build
group, not an extra spawn beyond it.

### Step 6 — independent verification, as a loop

After the builders return GREEN, the agents that *built* the change are not the ones that sign
off on it: **`qa-engineer` (role b)** runs the suite, applies the mutation mindset
([`tests-assert-behavior.md`](tests-assert-behavior.md)), confirms the hardened AC set is covered
and flags a simplification pass (tests-only edits); **the persona lenses, re-dispatched** against
the built diff, confirm the permutations they *specified* actually *hold* and catch a
persona-specific regression; **`doc-librarian`, re-dispatched**, verifies the doc plan was
satisfied — entries present, no new orphans, cross-links resolve.

**Verification is a loop, not a one-shot gate.** A gap from *any* verifier routes back to the
implementer whose layer owns it (re-running the architect's spec for that AC first if the spec was
under-specified); then **the same verifier re-runs against the new diff**. Repeat until every
verifier returns clean; only then does the change reach the PR cycle. A gap that cannot be
remediated escalates to the user via the `design-block` recipe rather than shipping silently.

**No finding is silently downgraded.** A Phase-1 lens finding the build did not implement holds
the verdict at **GAPS** unless it was explicitly fixed, or explicitly deferred with a recorded
rationale AND a tracked follow-up issue. A real requirement may not be reclassified as a
nice-to-have or parked in an "unverifiable" bucket — *"the unit layer can't assert it" is not
"safe to drop."* Real precedent: a lens flagged a retry trap in Phase 1, the build deferred it as
gold-plating, the acceptance pass absorbed it as "browser-only", and an external reviewer had to
catch it. The internal evaluator complements the external review cycle; it never replaces it.

### Step 7 — the PR cycle

Unchanged from [`pr-review-cycle.md`](pr-review-cycle.md): the orchestrator pushes, opens the PR,
and drives it to merge-ready; watching is delegated to `pr-checkin` and `pr-manager` per
[`parallel-pipeline.md`](parallel-pipeline.md); every fix is a routed dispatch, one fix-subagent
per finding, never a batch.

## Mediated hand-offs — the non-negotiable constraint

**Subagents run in isolated contexts and return exactly ONE result message. They do not talk to
each other.** A lens cannot hand its report to the architect; the architect cannot hand its spec
to a builder; a builder cannot hand its diff to the qa-engineer.

> The orchestrator reads agent A's returned output, distills the parts agent B needs, and bakes
> them into agent B's brief. The orchestrator is the integrator. Agents never call each other.

This is why the orchestrator — not any agent — owns the gate decision, the merge of parallel
reports, and the domain routing of builders: they are integration acts only the context-spanning
thread can perform. Any design that assumes agent-to-agent messaging is wrong for this harness;
the mediation is structural, not stylistic. Two corollaries:

- **Subagents do not inherit SKILL-level conventions.** A worker sees its brief plus the
  auto-loaded `CLAUDE.md` and path-scoped rules — never this file. Any behavior you need MUST be
  in the brief.
- **A roster agent merged mid-session is not dispatchable until a new session.** Claude Code
  snapshots `.claude/agents/` at session start; a mid-session addition raises
  `Agent type '<name>' not found`. Prefer a fresh session; the fallback (a `general-purpose`
  subagent with the charter pasted in) keeps the instructions but loses the enforced `tools:`
  allowlist.

## Root causes are HYPOTHESES, pre-verified cheaply

**Any root-cause claim carried into a brief is a hypothesis until a cheap disconfirming check
proves it — and that check runs BEFORE dispatch.** A root cause baked into a brief as fact forces
the downstream agent to spend its budget *refuting* it. Real precedent: an unverified "confirmed:
null foreign key" went into the lens briefs; the lenses burned a cycle disproving it against the
schema — a thirty-second check the orchestrator could have run first. So: label it
("hypothesis: the 500 is a null dereference on `<field>`"); run the cheapest check the claim
admits — a schema describe, a grep for the actual call site, a one-row select — aiming to
*disprove*, not confirm; and for runtime errors dispatch with the *observed* trace (the
reproduce-first artifact) plus the check result, never a code-read guess.

## Initial-build fan-out — the DEFAULT, by file ownership

**Splitting the build across specialists and dispatching them in parallel is the default for the
INITIAL build of every PR — not a fix-cycle-only mode, not an opt-in reserved for epics.** The
orchestrator's first question on any PR is "what are the separable concerns, and which specialist
owns each" — never "dispatch a builder." One generalist authoring the whole change serializes work
three specialists could do in parallel. Real precedent: most PRs were being split only on fix
cycles, never on the first build; the correction made the split the default from the first commit.

- **The contract precedes the implementers** — the only hard ordering. Backend, frontend and
  qa all author off the architect's contract, simultaneously; nobody queues behind a builder.
- **One isolated environment per PR.** Every PR is built in its own worktree, and ALL of that
  PR's agents work inside it.
- **Explicit, non-overlapping FILE ownership — by file list, not purely by directory.**
  `backend-expert` owns the server tree **plus its own named RED/feature test file(s)**;
  `frontend-expert` owns the view tree; `qa-engineer` owns **all other test files**. The test
  directory is split by specific file so two agents never touch the same path.
- **Each agent commits ONLY its own files: `git add <explicit paths>`, NEVER `git add -A`.** A
  blanket add sweeps a sibling's in-flight edits into the wrong commit, or races a half-written
  file. Every brief states its exact file set. Concurrent agents share ONE git index per worktree
  ([`capacity-and-worktrees.md`](capacity-and-worktrees.md)).
- **A pure single-domain PR collapses to fewer agents** — the split is the default, the collapse
  the exception.

Three execution patterns, chosen in order: **(1) split-by-file-ownership, parallel** (the
default); **(2) sequence in the shared worktree** when concerns genuinely overlap on the same
files; **(3) separate worktree per concern + merge** only for concerns large and independent
enough that index contention would dominate. All three keep the stop-after-commit contract. The
**fix cycle** uses the same routing — each finding to the specialist whose layer it lives in, one
fix-subagent per finding; folding separated findings into one fixer re-serializes what the routing
just parallelized. Liveness probe and failure recipes: [`threading-model.md`](threading-model.md).

## Guardrails — cost and isolation

**What an ensemble costs.** Roughly **6–7x the context** of a single subagent doing the same work
— each agent in its own window, plus the orchestrator reading every result. The gate is the
primary cost control; everything below applies *after* it has routed to Band 3.

**When it is malpractice.** A full fan-out on a one-line fix, a copy change, a single-domain
sub-3-AC issue. The tax is justified only where separated perspectives demonstrably reduce
missed-state risk: a genuinely multi-criteria, multi-domain, concurrency- or lifecycle-sensitive
change.

**The isolation contract for parallel implementers.** Agents sharing one test database collide on
schema resets — one agent's reset truncates the rows another is mid-assertion on, a **false**
failure that reads as a real regression (a real incident). So: one isolated test database per
worktree, a **copied** (never symlinked) environment file so the override is visible inside the
test container, and the application base path pointed at the worktree so a dependency-directory
symlink does not run main's code ([`capacity-and-worktrees.md`](capacity-and-worktrees.md)).

**Depth versus the concurrent-subagent cap.** An ensemble run produces ONE PR and counts as one
toward the open-PR band, however many agents it spawned. Its *internal* fan-out can still approach
the runtime's concurrent-subagent cap: never dispatch the whole chain as one burst and then block
on slots you are holding yourself. Stagger by phase — only the lens group and the build group are
ever genuinely concurrent — and run a group in two waves rather than waiting on a slot the pending
spawns are blocking.

**Compounding-error containment.** Each hand-off is a seam where a misread brief becomes a wrong
design a builder implements faithfully, with no peer to catch it. The containment is structural:
the architect's RED spec between design and build, the independent `qa-engineer` evaluator, the
dual-phase lens acceptance pass, and the no-silent-drop rule. **No builder output reaches the PR
cycle without clearing a failing test the architect specified and an independent evaluator.**
