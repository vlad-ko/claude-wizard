# Context economics — what a session costs, and the levers that move it

> Loaded on demand by the wizard SKILL. The always-on summary lives in the SKILL body
> ("Core Identity"); this file holds the cost model, the summary+pointer budget for
> always-resident files, the orchestrator hygiene practices, model-tier routing, and the
> succinct-communication rule.

## The cost model

Warm-cache read spend in a long agentic session is approximately multiplicative:

```text
spend ≈ (resident context size) × (API round-trips per turn) × (turn count) × (cache-read rate)
```

Every term is an independent lever, but the multiplication means a large context makes *every
other term worse* — a fat baseline is paid again on every round-trip of every turn. Three facts,
each measured on real session transcripts, carry the whole model:

- **Reads dominate.** Across a full session archive the cache-read to cache-write token ratio was
  roughly **63 : 1**. Cache cost is essentially `context_size × call_count`, not a write problem;
  a change that only writes less new material barely moves the needle.
- **Every always-resident byte is re-read on every API call.** The turn-zero baseline (system
  prompt + `CLAUDE.md` + memory + agent roster + skill) was measured at **86k–141k tokens** before
  any work started. One session rode a single context toward the full window over 14,000 calls,
  averaging ~545k tokens per call.
- **Context is a ratchet, not a one-time cost.** 100k of raw tool output pulled inline into the
  orchestrator is paid again, in full, on every later call for the rest of the session.

**The TTL trap.** A wake that arrives past the live cache TTL cannot hit the cache — it pays a
full cache **write** (1.25–2x the input rate) instead of a read (~0.1x). So a slow tick on a large
context can cost *more* per fire than a fast tick on a small one. The consequence is a sequencing
rule, not a reversal of event-driven wakeups: **shrink the baseline first**, because a small
context is cheap to re-read whether warm or cold, and then the TTL stops mattering.

**Caches are per model.** There is no cross-tier cache handoff — "have a cheap model warm the
cache for an expensive one" is architecturally impossible. What achieves the intent is
delegation: a cheap-tier subagent reads the bulk material in its *own* context and returns a
distilled verdict; the orchestrator caches only the verdict.

**Levers, ranked by measured leverage:** (1) baseline context size — multiplies every read;
(2) session length / the ratchet — a milestone reset pays one summarization and resumes small;
(3) round-trips per turn — each tool round-trip re-reads the *entire* accumulated context;
(4) model tier — a ~10x spread in cache-read rates, listed last because it only multiplies what
the first three produced.

## The summary+pointer budget for always-resident files

`CLAUDE.md`, every `SKILL.md`, and every `.claude/agents/*.md` definition is loaded on every
session or every dispatch that uses it. Its size is not an authoring cost; it is a **recurring,
multiplicative** cost paid by every future turn. Real precedent: roughly 60% of one project's
`CLAUDE.md` bytes sat on lines carrying an inline issue or PR reference — the citation-and-
precedent lines, not the rules.

The growth mechanism is always the same: a rule ships correctly (imperative + one-line why +
pointer), and then each later incident that validates it gets **appended as narrative** instead of
**routed to the method doc**. No single edit is wrong; the file accretes.

**The operative / evidentiary split.** An always-resident file does at most two jobs, and only
one belongs resident:

- **OPERATIVE — what to do.** The imperative, the enumeration a check actually iterates, an
  enforcement identifier, a command that must be typed exactly right, an anchor another file
  links. Read and used on every turn; keep it resident.
- **EVIDENTIARY — why the rule exists.** The incident narrative, the motivating PR, the worked
  example. Read only when someone doubts the rule — and at that moment they follow the pointer
  anyway. Do not pay for it on every turn just in case.

**The one-question test**, for every reference, precedent sentence or example you are about to
add to a resident file:

> **Do you need this to DO the work, or is it a story about why the rule exists?**

Operative → keep. Evidentiary → **move** it to the method doc (verify the doc carries it *before*
cutting the resident copy — move, never delete). **Target shape per rule: imperative statement +
one-line why + pointer.** One or two lines.

What counts as operative and must not be cut: an enumeration a procedure iterates (a banned-shape
list, a four-rung ladder — dropping an item changes coverage, not color); an enforcement
identifier (a lint rule name, a CI check name); a heading or path another document links (grep
the repo for the old slug before rewording any heading — diff `grep '^#'` before and after); the
exact syntax of a command whose wrong form does the wrong thing silently.

The same split, different vocabulary: a `SKILL.md` carries the **ordered step**, its
`reference/*.md` carries the **method**; an agent definition's body carries the **rule the agent
follows**, a linked doc carries the **why**.

## Path-scoped rules load lazily; eager imports do not

Rules that apply to a *place* in the codebase belong in `.claude/rules/<name>.md` with a path
glob: they load once a matching file is read — in the session and in dispatched subagents alike —
so a session that never touches that path stops paying for them. The limit worth knowing: loading
is **reactive**, present before you act on the file but not at session start, so a rule that must
apply unconditionally stays in `CLAUDE.md`.

**Do not convert path-scoped rules to `@` imports.** `@` is eager and restores every byte the
move removed; it is not a lazier spelling of the same thing.

## Orchestrator context hygiene

You pay for your whole resident context on EVERY call, and you control all three terms of the
product. Three practices — honest rung: practices, not mechanisms.

- **Delegate high-volume sweeps to a subagent that returns a compact verdict.** A multi-call host
  CLI loop, a bulk log read, any paginated listing — run it in a subagent's context, not yours.
  Real precedent: ~23 reviewer findings were fetched and judged by a mid-tier subagent; the raw
  JSON and comment bodies never entered the orchestrator's context, only the verdict did. The
  banned shape is the same loop run inline, which pulls every body into main context and re-pays
  it on every later call.
- **Reset at MILESTONES, never mid-investigation.** A cohort merged, an epic phase complete, a
  handoff — those are the boundaries where a summarization pays for itself. Resetting mid-task
  loses working state; never resetting rides one context to the window's ceiling.
- **Batch independent calls in ONE block.** Each round-trip re-reads the entire context;
  sequential single-call turns for independent reads multiply that for no benefit.

## Route mechanical agents to a cheaper tier

Cache-read rates differ roughly 10x across model tiers. An agent whose inputs are mechanical and
whose output is a fixed-shape verdict — `pr-checkin`, a triage-manifest emitter, a ledger writer —
does not need the orchestrator's tier. Pin it once, at the definition level, with `model:`
frontmatter in `.claude/agents/<name>.md`, so the tier is set by the author rather than
re-decided per dispatch. `pr-manager` and the builders stay at their own pinned tier; judgment
passes are not the place to economize.

Tier is the last lever for a reason: routing a fat, ratcheted, un-batched session to a cheaper
tier recovers a fraction of what fixing the first three terms recovers outright.

## Succinct communication — on every channel

**Say it in the fewest words that stay true** — chat, PR bodies, issue bodies, commit messages,
review replies, subagent briefs. The bar is the **one-sentence test**: state the goal, the
finding, or the outcome in one sentence first. If you cannot, you do not yet understand it well
enough to write more.

- **Lead with the answer.** No preamble, no recap of what was asked, no narration of what you
  are about to do.
- **Structure only when it earns its place** — a table beats six paragraphs; six paragraphs never
  beat a table.
- **Cut every sentence that does not change what the reader does next**: restated context,
  hedging, self-commentary about process.
- **Detail belongs where it is looked up, not where it is broadcast** — evidence into the PR body
  or the issue, not into chat. **Exception:** a recipient who must ACT on the evidence gets it in
  full — a subagent returning an adjacency block for verbatim transcription, or a routed fix
  brief, is not chat.

**This governs LENGTH, not honesty.** Never buy brevity with an unverified claim, an omitted
caveat, or a finding left unmentioned — those are reported, briefly. It does not repeal the
merge-ready phrasing rule of [`pr-review-cycle.md`](pr-review-cycle.md), which governs the
*accuracy* of a conclusion, not its word count.

## Measure, do not assert

Every claimed reduction is verified against a real measurement — an estimate is not evidence.
Compare **ratios** (average context per call, calls per turn), not absolute totals, because
sessions differ wildly in scope; a single before/after pair is anecdote, look for the trend across
several sessions; and a nonzero unparsed-record count makes the affected metric **inconclusive**,
not approximately right ([`absence-is-not-a-value.md`](absence-is-not-a-value.md)).

**Honest rung.** Nothing here is mechanically enforced except what you build: a size-budget check
on the resident files that fails a commit when they regrow, and `model:` frontmatter that pins a
tier once. Batching, delegation, milestone resets and the one-question test are practices a
session has to follow.
