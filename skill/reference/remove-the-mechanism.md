# Remove the mechanism, do not add a guard

> Loaded on demand by the wizard SKILL. The always-on summary lives in the SKILL body ("Remove
> the mechanism, do not add a guard"); this file holds the operative test, the four-rung ladder,
> the honest-rung reporting obligation, why a feature flag is a guard, and why removing a
> mechanism from a live system is a multi-release operation.

**The rule:** when a defect lets the system do something it must **never** do, remove the
**mechanism** that permits it. Do not add a guard that declines it.

A guard is a conditional at one call site. It patches the path you happened to find, leaves every
other path free, and makes correctness depend on each future author remembering to check.
Removing the mechanism means restructuring so the wrong action is **not expressible at the type
or API** — or, one rung down, **not reachable except through one authoritative seam** every
caller must pass, ideally backed by a database constraint so the invariant survives a code path
nobody has written yet. Those are different guarantees, not synonyms, and the difference is where
this rule is usually got wrong.

This is the systemic-fix instinct applied to a **capability** rather than to a set of call sites:
"fix ALL places with the same pattern" subtracts every *instance*; this rule subtracts the
*mechanism* that lets instances exist. A guard is the one-off fix that instinct forbids, wearing
the clothes of a fix.

## The operative test

> **After the fix, can a NEW caller — written next year, by someone who has not read this issue —
> still do the wrong thing?**

If yes, it is a guard. That is the whole test, and it is deliberately about the *future* caller
rather than the current diff: every guard passes a review of the code that exists today, because
the author just fixed the one path they were looking at.

A second formulation, for a **type- or schema-level** claim specifically: **a reviewer must be
able to state, from the type signatures and the schema alone, why the wrong action cannot be
constructed.** If verifying that claim requires reading call sites, the type does not carry the
guarantee and the mechanism still exists. An authoritative *seam* is verified the other way round
— enumerate every writer and show each one converges on the seam — so call-site inspection is
what that rung *requires*, not evidence that the removal failed. Do not apply the type-signature
test to a seam and conclude that a valid removal is a guard.

### Tells

| It is a guard when... | It is a mechanism removal when... |
|---|---|
| the diff adds a condition (`if`, an extra column check, an early return) to an existing method | the diff changes a shape — a type, a constructor, a state machine's edges, a schema constraint |
| the fix is scoped to the entry point named in the bug report | the fix is scoped to the seam, and the reported entry point is one of N callers that now converge on it |
| a second, third, fourth caller could reach the same write without the condition | there is no second path — reaching the write requires passing the seam |
| correctness depends on the next author reading a comment or remembering a rule | correctness holds for an author who has never heard of the issue |
| the wrong value is *unset* / *filtered out* / *not rendered* | the wrong value is **unconstructable** — no field to read, no enum case, no legal edge |

The last row is the sharpest. "We do not display an unconfirmed election" is a guard. "An
unconfirmed election produces no value, so there is nothing to display" is a removal.

## Two precedents

**1. The misrepresented election.** A platform recorded a user's election in its own database but
never transmitted it to the external system that actually executed the order and issued the
authoritative record. The platform therefore reported that an action was taken which was never
taken. The ruling: the fix must be such that *the system has no mechanism to misrepresent* —
across every current and future integration. That scope is exactly what rejects a per-integration
guard: a runtime `if (external_confirmed)` at each display site is a check someone must remember
at the fourth site. What removal implied instead: the displayed value is **derived from confirmed
external state**, not from recorded intent — the field that records what we *wanted* is itself
the mechanism; and per-integration capability lives **in the type the call site is handed** — an
integration that cannot accept the election makes it unconstructable, not merely unset. Design
first for the integration where the fact can *never* be proven; a design that works there works
everywhere.

**2. The double collection.** A fee-application path moved money and marked a record applied,
but only wrote the "succeeded attempt" row when the record had come through a newer pre-flight
axis. A separate manual-recording path was reachable for the same record from a live route; its
idempotency guard looked for that attempt row, found nothing, and collected again. Two columns
(`status`, `collection_state`) could disagree; one path wrote one, the other read the other. The
ruling: collection is a **singleton operation regardless of which path the record comes from** —
one state machine, one authoritative transition at the seam, so every writer present and future
converges by construction. Explicitly rejected: adding a `status` check alongside
`collection_state` in the second path, because that patches the one entry point found and leaves
every other path free.

**The instructive detail:** a database constraint *already existed* — a unique index making a
second succeeded attempt per record physically impossible. It did not prevent the bug, because
the legacy path moved money **without writing an attempt row**, so the constraint never saw that
collection. **A constraint removes the mechanism only when every path is forced through the
artifact the constraint keys on.** Adding the constraint is not the end of the work; routing
every writer through it is.

## The escalation ladder

Take the highest rung the change can reach. Each rung down widens the set of future callers that
can get it wrong. **These are four different guarantees, not four phrasings of one.**

1. **Inexpressible in the type or API.** No field to read, no enum case to select, no constructor
   that accepts the bad state, a value object that cannot hold it. The compiler and the reviewer's
   eye do the work; nothing has to run for the wrong action to be impossible.
2. **Unreachable outside one authoritative seam every caller MUST pass through.** A single
   guarded transition, a single service method that owns the write, a single factory. The wrong
   action is still *expressible* in principle but not reachable without the seam, so a new caller
   inherits the invariant instead of re-deriving it. **The word *must* is load-bearing.** If any
   caller can reach the write around the seam, this is rung 4 wearing rung 2's clothes — which is
   how the double collection happened. Rung 2 is claimable only after enumerating the writers and
   showing each one converges. Where a seam can be gone around by a new class whose author forgets
   to opt in, a **static-analysis rule that requires the opt-in** mechanises the enumeration; a
   rung-1 guarantee would need no such rule, a seam does.
3. **Rejected by a database constraint.** A unique index, a foreign key, a `NOT NULL`, a check
   constraint. This rung survives a code path nobody has written yet — a console command, a
   seeder, a repair script, a future service. Its limit is precedent 2: it binds only on the rows
   and columns it keys on.
4. **An application check.** A condition in code. This is a guard, and it is the rung the rule
   exists to discourage.

**Sometimes rung 4 is genuinely all that is available** — the invariant spans systems, the
constraint needs a schema change that cannot ship this release, the seam does not exist yet and
building it is its own epic. That is a legitimate outcome. What is not legitimate is presenting
it as structural.

## Honest-rung reporting — say it in the PR

**When the fix lands at rung 4, say so explicitly in the PR description:** name the rung, name
what blocked the higher one, and file the follow-up that reaches it. A stated guard is a tracked
obligation; an unstated one is a bug the next author will re-introduce, having reasonably assumed
the invariant was already held.

The same honesty applies to a partial climb. "Collection now converges on one seam for the four
writers that exist; the DB constraint is deferred to the filed follow-up" is a good PR sentence.
"Fixed double collection" is not.

**There is no lint for this.** Whether a fix removes a mechanism or declines an action is a
judgment about shape, not a pattern a static analyzer recognises. The enforcement points are the
Phase 7 self-review checklist, the AI review cycle, and a reviewer asking the operative test out
loud. Do not claim otherwise in a PR — an unsupported claim of structural enforcement is worse
than an honest guard, because it stops anyone from looking again.

**A throwing `default` arm is not an exception to this rule** — it is rung 1's guarantee expressed
at runtime: an unhandled state fails loudly at the call site instead of rendering a plausible
label. The opposite of a `default` arm that returns a benign value
([absence-is-not-a-value.md](absence-is-not-a-value.md)).

## A feature flag is a guard over an open obligation

A feature flag is a **safety mechanism with one purpose**: prevent a user accidentally triggering,
from the UI, a downstream path that is incomplete or unsafe. It gates the **reachability of a
surface**. Nothing else.

**The discriminator — ask one question.** *Is the thing behind it finished and working, merely
not wanted in this environment?* Then it is an **environment setting** — configuration read from
the environment, not a flag. *Is the thing behind it incomplete, or unsafe for a user to trigger?*
Then it is a **feature flag** — gate the UI surface, and **the work stays owed**.

**The naming rule has teeth:** environment configuration keeps the `*_ENABLED` env-key shape;
feature flags are class-based, never env-named, never set by a deploy. **If a proposed flag has
an env key, it is configuration and does not belong in the flag system.** Precedent: an epic's
research classified every existing `*_ENABLED` key as an "ad-hoc feature flag" and planned to
migrate them; the correction was that none were flags — nothing behind them was unfinished — and
the flag system started **empty**. Had the miscategorisation stood, the first phases would have
moved working configuration into a mechanism that adds an admin surface and an audit trail to a
question the environment already answered.

Where a flag sits on the ladder, honestly: a flagged-off surface is genuinely absent (a direct hit
404s, never a placeholder that advertises the entry point) — strong containment *of the surface*,
but a flag hides an entry point, it does not quarantine code. A scheduled job, a queue worker, an
observer or a console command reaching the same chain passes through no surface. So a flag is
**rung 4 with a name: a temporary guard over an open obligation.** State it that way in the PR,
prove no non-UI trigger reaches the chain, and file the work whose completion is the flag's
removal condition. **A flag is never the fix for something the system must NEVER do** — hiding
the button that reaches X guards one entry point, and next year's caller does not use the button.

The failure mode this prevents: a surface is flagged off, the obligation is quietly dropped, and a
year later nobody remembers whether the thing behind it was finished or abandoned — still there,
still off, nobody dares remove it. That is "fully tested, never wired"
([adjacency-check.md](adjacency-check.md)) arrived at deliberately.

## The removal condition

Every guard carries one, and it must be **satisfiable**: the concrete state of the world at which
the conditional is deleted. For a feature flag it is the chain verified complete end to end —
never a staleness timer expiring. For a rung-4 fix it is the higher rung landing. For an interim
guard during a migration it is the contract phase shipping. Write it into the PR and the filed
follow-up; a guard with no removal condition is permanent by default.

## Removing a mechanism from a live system is a contract-phase operation

The mechanism you are removing is, by definition, something running code currently uses.
Deleting it in one release breaks the old revision still serving during a rolling deploy. So the
removal decomposes like an expand/contract migration:

1. **EXPAND** — add the new seam / type / constraint-compatible shape additively, alongside the
   old mechanism. No caller switched, no behaviour change.
2. **MIGRATE** — move callers onto the seam one at a time; backfill any data the constraint will
   require. During this window an interim guard on the known-bad path is reasonable **temporary
   scaffolding** — labelled as such in the issue, with the contract phase filed, so it is not
   mistaken for the fix.
3. **CONTRACT** — in a separate later release, once no revision reads it, delete the old mechanism
   and add the constraint. **This is the step that actually removes the mechanism.** The issue is
   not closeable at step 2.

The phase list on the issue *is* the ledger for this ([phased-decomposition.md](phased-decomposition.md));
the contract phase is a filed phase, not an aspiration.

## Related

- [absence-is-not-a-value.md](absence-is-not-a-value.md) — the refusal is the *posture*; this is
  the *shape*. "Return inconclusive instead of `0`" applied structurally means the caller cannot
  receive a fabricated number at all.
- [adjacency-check.md](adjacency-check.md) — when the outward question finds a fact stated at N > 1
  sites, the remedy is this rule (collapse to one expression), not teaching all N.
- [phased-decomposition.md](phased-decomposition.md) — the phase shapes the expand / migrate /
  contract sequence lands as; and the claim discipline that an AC names the EXISTING seam it
  modifies, which is this rule moved to specification time.
