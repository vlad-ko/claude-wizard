# The adjacency check — a diff is checked against the known-defect inventory

> Loaded on demand by the wizard SKILL. The always-on summary lives in the SKILL body ("The
> adjacency check"); this file holds the portable pattern inventory, the two questions run
> against the diff, the routing table that keeps the check cheap, the required PR-body block,
> the doc-corpus form, and the decline contract.

**The rule:** a fix is checked against the **known-defect pattern inventory**, not only against
its own bug. It must be complete along its own pattern (every site of the pattern you were
looking at) **and** create no new instance of a *different* pattern in an adjacent system.

**Why those are two questions.** "Fix ALL places with the same pattern" looks **along** the
pattern you are already holding: you found a stale value read, so you grep every stale value
read. It points outward from the defect. This rule looks **across the boundary of your own diff**:
whatever you just wrote is code, and code written today is subject to exactly the same failure
shapes as the code you are repairing. A fix can be flawlessly complete along its pattern and
still be a fresh instance of another one. Real precedent: a fix that added an `unmeasured` bucket
to a dashboard — a correct absence-is-not-a-value remedy — built it on a denominator that ranged
over a different set than the measurer, producing a permanent, unclearable false alarm. Complete
along its own pattern; a new instance of "absence renders as healthy" in the same diff.

## The inventory — closed, filed, not re-derived per PR

Keep your inventory as a **closed list of filed pattern epics**. A closed list is what makes this
check take minutes instead of an afternoon; a private taxonomy invented per PR is unreviewable.
The seven below were derived from one adversarial sweep of a production system and are portable —
start from them, and add an epic only when a finding maps to none.

| Pattern | The diff signal that selects it |
|---|---|
| **One fact, many implementations** — a derived fact stated at N sites, and a fix or convention that never propagated | you changed a derived fact: a count, a status, a label rule, a basis, an eligibility test |
| **Absence renders as healthy** — a missing/empty/failed read coerced into a clean-looking value | you added or changed a default, a bucket, an empty-state, a zero-state, an alarm |
| **The guard that cannot fail** — a test, lint rule, constraint or invariant whose trigger excludes the case it is assumed to cover | you relied on an existing guard / rule / invariant / constraint to cover your change |
| **Fully tested, never wired** — a capability with green tests and no production caller | you added a capability, a service method, a flag, a column, a command |
| **The fixture encodes the defect** — a test whose expected value or fixture makes the bug the contract | you added or edited a test or a fixture |
| **Boundary and unit arithmetic on money and time** — totals, denominators, rounding, units, periods, set differences | you touched any of those |
| **Unlocked check-then-write races** — a read-then-write or "is there already one?" outside the lock | you touched a read-then-write, a status transition, an existence check |

**When a finding maps to none of the seven, that is an eighth epic — file it.** The inventory's
closure is its cheapness and also its blind spot; the maintenance rule keeps the blind spot from
becoming permanent.

## The two questions

Both are run against the **diff**, not against the bug report. The bug report has already been
read carefully by everyone; the diff has been read carefully by nobody, because its author wrote
it.

### Q1 — OUTWARD. Every fact this diff now states: where ELSE is that fact stated, and do they now agree?

A "fact" is any derived proposition the system asserts: *this record is compliant*, *this
account is billable*, *this surface is empty because nothing drifts*, *this item may be bought*.
**Name it in words first** — if you cannot say it in a sentence you cannot grep it.

Then grep it across **every layer that can express it**:

```text
model / query scope -> service -> controller / view-data -> view layer
-> assistant-tool / export payloads -> console commands + scheduled jobs
-> health invariants -> seeders / factories / fixtures
```

The layer list is not decorative: the same defect once recurred three times inside one PR, each
time one layer further out.

**If N > 1, the remedy is [remove-the-mechanism.md](remove-the-mechanism.md), not diligence.**
Teaching all N sites the new rule is a guard applied N times; the N+1th site, written next year,
will not know. Collapse to ONE authoritative expression — a typed value the consumers render
rather than derive — and let the others read it. Enumerating the sites is this rule's job;
collapsing them is that rule's.

#### Q1 in a doc corpus — count SITES, not files

A fact — a CI gate precondition, a required context, a scoring rule, a retired control — is
stated in prose more often than in code, and prose is where the OUTWARD check has failed most
often: five doc-touching PRs each spent a median of ten commits and four reviewer rounds
re-correcting a claim the diff had already "updated". Four rules, each the exact defect one of
those PRs shipped:

1. **Count SITES, not files.** One file can state the fact five times; editing it once is not
   agreement. "All three docs updated" was reported with seven sites still live.
2. **Grep the CLAIM, case-insensitively, with its paraphrases.** The symbol appears where code
   references it; the claim appears in comments, job names, log strings and docs, in English. One
   PR swept "clean" three times while sites remained. Grep a distinctive noun that survives every
   paraphrase, and **write the pattern and the hit count into the block.**
3. **A doc you touch adopts its pre-existing stale claims.** Reviewers read the whole changed
   file, not the hunks. Read every doc you edit end to end once, reconcile everything stale in
   the same commit, and check the file against ITSELF first — a self-contradiction is the
   highest-yield tell.
4. **When a workflow's triggers or gate preconditions change, grep the WORKFLOW FILENAME across
   the whole tracked Markdown corpus** first — `git grep -iln '<workflow>.yml' -- '*.md'`. **Bound
   the sweep by file TYPE, not by directory** — a directory list is the same N-sites shape this
   rule exists to catch.

The block's line for this is the pattern and the count, never "all sites updated": a pattern can
be challenged by a reviewer; a claim of diligence cannot.

### Q2 — INWARD. Every fact this diff RELIES on: which guard proves it, and CAN that guard fire here?

The failure shape is precise: **gate silence is not evidence.** A static-analysis rule, a DB
constraint, a health invariant, and a test all have trigger conditions, and a change that falls
outside the trigger produces the same green as a change that satisfies it.

So the check is not "did CI pass". It is: **open the guard, read its trigger, and state why your
case is inside it.** One sentence. If your case is outside the trigger, you have found a
guard-that-cannot-fail and you own it — extend the guard in this PR if that is a one-line
widening, or file it and say in the PR that your change is currently unguarded.

Real precedent: a new money-path model was transitively tenant-owned through a parent, and the
tenant-scope lint rule's own docblock said it deliberately did not force transitively-owned
models. An author who opened that file would have read their own case being excluded. The rule
was conservative by design — the defect is not the rule, it is treating its silence as coverage.

## The routing table — how this stays cheap

**You do not run seven audits.** A diff's *actions* select at most two or three rows, and each row
has one grep the builder has usually already run. Read down the left column; skip every row that
does not describe your diff.

| If the diff... | Pattern | The one thing you actually do |
|---|---|---|
| changed a derived fact a second surface also derives | one fact, many implementations | grep the fact across the layer list; **list the sites in the block** |
| added/changed a count, total, denominator, bucket, or set difference | absence + arithmetic | name the SET each side ranges over; prove both sides range over the SAME set |
| added/changed a default, empty-state, zero-state, or alarm | absence renders as healthy | state what a human sees when the input is absent, whether they can tell it from a measured value, and how the state CLEARS |
| added a model, table, column, service method, flag, or command | guard that cannot fail + never wired | name the guard that should cover it and why it fires; name the **production** caller (not the test) |
| added or edited a test or fixture | fixture encodes the defect | the mutation, and a fixture whose quantities are deliberately unequal ([tests-assert-behavior.md](tests-assert-behavior.md)) |
| touched a read-then-write, status transition, or existence check | check-then-write race | state whether the read is inside the transaction and under a row lock |
| **reused an existing expression as building material** | **all** | **check whether that expression is itself an inventory instance before you build on it** |

That last row is the cheapest and the one the false-alarm precedent needed: its denominator was
**already wrong before the fix** — an archived record was already counted compliant. The fix
reused an un-inspected expression and promoted a silent error into a permanent alarm.

**Scope.** Every row describes a code action, so a docs-only diff selects none of them — but the
**doc-corpus form of Q1** is selected by editing any document that states a system fact, which a
docs-only diff does by definition.

## The artifact — no artifact, no check

Only artifact-producing steps bind; a preference loses to momentum. The artifact is a block in
the **PR body**, one line per applicable question:

```text
### Adjacency check
- Same-fact sites: "<the fact, in words>" is expressed at N sites: <file:line list>.
  This PR changed <M>. <all N / collapsed to <seam> / why the others are correct as-is>
- Doc-corpus sites: grepped <pattern> case-insensitively over <corpus> -> <H> hits in <F> files;
  reconciled <R>. <the ones left, and why they are correct as-is>
- Set agreement: <bucket/total> = <expression>. Left ranges over <set A> (<citation>),
  right ranges over <set B> (<citation>). Same set: <yes, or the fix>.
- Guard: covered by <guard>, which fires because <your case is inside its trigger>.
  / NOT covered by <guard> because <trigger>; filed as <issue>.
- Production caller: <the non-test caller of the new capability>.
- Declined adjacent fix: <site> — routing it through <seam> would <traced consequence>
  because <cited reason> — filed as <issue>.
```

**Only applicable lines appear.** A missing line means neither the routing table nor the
doc-corpus form selected it; that is the design, and it is why the block is usually two lines. A
block with all six lines on a one-file diff is a sign somebody is performing the check rather
than running it. A block asserting "same set: yes" with no citation is worth nothing, and only a
reviewer can tell — the artifact's presence is checkable, its quality is not.

**Delegated mode:** builders do not write PR bodies. The **subagent returns the block** in its
result message; the **orchestrator transcribes it verbatim** into the PR body. A block
paraphrased by the orchestrator is no longer the builder's claim. A reviewer reporting "block
missing" is answered by grepping the LIVE PR body for the literal heading, not your draft.

## Declining an adjacent fix — the default, and it is not free

**What is narrow is the PR, never the fix.** Three outcomes:

- **Finding an adjacent problem — ALWAYS right.** It is the point.
- **Fixing it in place — almost always wrong.** It is another phase or another issue
  ([phased-decomposition.md](phased-decomposition.md)). "Out of scope for this PR" means *another
  phase*, not *not our problem*.
- **Leaving it unfiled — ALWAYS wrong.** An instance that vanishes from the ledger is an instance
  nobody comes back for.

| Disposition | When |
|---|---|
| **Fix now, in this PR** | it is on the same pattern as the briefed fix (completeness along the pattern) AND the change is the one-line widening of a guard you already opened |
| **File it, note in the PR body** | anything else — a different pattern, a different phase, a consequence you traced and declined |
| **Note in the PR body only** | never: a body note without a filed issue is the "unfiled" outcome with extra steps |

**The decline costs one traced sentence:** the site, the consequence of "fixing" it, and the
filed issue. The standard to imitate: a builder found a second service bypassing the price seam
it had just introduced — an obvious, tempting, one-line extension — and instead traced what the
"fix" would do: for a *resolved* delisting the seam returns null and the holding is skipped, so
routing the bypass through it would newly enable **buying a resolved-delisted security**, because
the buy guard refuses only *pending* resolution. It returned a finding.

**If you cannot trace the consequence, you know enough to do neither** — not enough to fix it,
not enough to decline it. "I looked and it seemed fine" is the reasoning that ships the
guard-that-cannot-fail. Return it to the orchestrator as an open question.

## What this will NOT catch

Stated plainly, because a rule that overclaims stops people looking again.

- **A pattern not in the inventory.** The list is closed on purpose; new shape, new epic.
- **A wrong premise.** A faithful implementation of a wrong design passes. Reading an inherited
  AC adversarially is the builder brief's job, and it is cheaper there.
- **Runtime reachability.** Grep misses dynamic dispatch — container bindings, config class
  strings, template includes, event maps. The strongest supportable claim is "no static caller
  found", never "this is dead".
- **Production frequency and blast radius.** Not knowable from source; this cannot rank findings.
- **Rendered output.** Markup and layout belong to the browser layer — which is exactly why a
  view that DERIVES a fact must become a typed view-data value the controller hands over: collapse
  the sites to one and the fact becomes testable for the first time.

**There is no lint for this** — it is an application check on the mechanism ladder, a
design-review rule. One piece CAN be mechanised and should be tracked honestly as a higher rung
rather than claimed here: a quality-gate check that the PR body carries the block when the diff
matches a routing-table trigger. It enforces the artifact's PRESENCE, never its quality, and must
fail **closed** on an unreadable diff — an absent block and an unparsed one are not the same
outcome.

## Related

- [remove-the-mechanism.md](remove-the-mechanism.md) — the remedy when Q1 returns N > 1.
- [absence-is-not-a-value.md](absence-is-not-a-value.md) — the sibling rule Q2 most often invokes,
  and the reflexive direction: a fix FOR it can produce a harm OF it.
- [tests-assert-behavior.md](tests-assert-behavior.md) — the fixture-encodes-the-defect row.
- [phased-decomposition.md](phased-decomposition.md) — where a declined adjacent fix goes.
