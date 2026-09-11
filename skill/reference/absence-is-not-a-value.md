# Absence is not a value — refuse, never substitute a default

> Loaded on demand by the wizard SKILL. The always-on summary lives in the SKILL body ("Absence
> is not a value"); this file holds the banned-shape catalog, the refusal posture, the
> propagation obligation, the exception-path form, and the Three-Outcome Audit for anything
> that produces a verdict.

**The rule:** relying on the language's default coercion for a missing, empty, or failed read
is a MUST NOT. **A read that cannot produce a trustworthy answer must refuse** — return an
explicit inconclusive, throw, or raise a durable operator-visible artifact — **never substitute
a plausible number a human will trust.**

## Why this recurs

Nobody decides that an unpriced holding means zero drift. It **falls out.** The happy path gets
designed; the unhappy path is left to whatever the language does by default, and every
mainstream default turns absence into `null` / `0` / `false` / `""` — values that coerce into
*plausible numbers*. `null` in arithmetic is `0`. `null` compared to a threshold is "in band". An
empty collection sums to `0`. A lookup that matched nothing returns `null`, and a property read
on it is `null` again.

That is what separates this from an ordinary bug class: it is the **default behaviour**, so it
happens on every surface where somebody did not actively prevent it. And the harm skews severe
because the defect renders as a *confident, ordinary-looking number* — nothing looks wrong to
the person reading it.

Real precedent, one adversarial sweep, one day: a deploy-time error-rate soak whose monitor
polls all returned no usable count reported "soak clean (peak 0)" — the automatic rollback it
armed had **never been armed on any production deploy** while the log claimed success. The same
sweep found a holding with no price rendering as total value `0`, drift `0.00`, "in band",
nothing logged; a scheduled transfer that resolved no funding source crediting cash with no pull
ever issued; and an active account with no valuation snapshot invoiced on a silently partial
basis. Two things read off that list: **the fail direction was always UNSAFE** (absence became
clean / zero / in-band / settled, never held), and **no row had an operator-visible artifact** —
a substituted value looks exactly like a measured one.

## The banned shapes

A rule that does not name shapes is not actionable. Every one of these is a candidate on sight:

| Shape | What it manufactures |
|---|---|
| `x ?? 0`, `x ?: 0.0`, `(float) null`, a default parameter standing in for missing data | a measurement that was never taken |
| `first() ?? <default>` / `find() ?? <default>` | a fabricated record |
| `first()` / `find()` returning null into arithmetic, a property read, or a comparison | `0` / `null` / `false` at one remove |
| an empty-collection `sum()` / `avg()` treated as a real total | "summed to zero" indistinguishable from "had nothing to sum" |
| a silent `continue` / `filter` dropping an element from an aggregate | an aggregate over a *different set* than its label claims |
| a `match` / `switch` `default =>` arm returning null or a benign value | an unhandled state rendered as a plausible one |
| a swallowed `catch` returning a default, a "no adjustment", an empty result | a failure rendered as a success (see the exception-path form below) |
| a threshold compared against an absent value | `null > threshold` is `false`, i.e. "in band" |
| an unvalidated CLI option cast to a number (`int("abc")` is `0`, `int("30x")` is `30`) | a fabricated bound the command acts on and reports as real |
| a bare flag read by VALUE rather than PRESENCE (`--days` with no value binds to the same `null` as no flag) | the code-side default applied to an operator who asked for a bound and gave none; when the flag selects a *filter*, the failure widens to the whole population |
| shell `${count:-0}`, jq `// 0`, an unchecked `count=$(cmd)` whose empty output later coerces to `0` | a confident zero after the producer failed |

**The defect is never the operator.** `:-` falls back only on unset/empty, `//` only on
null/false, `??` only on null — all three correctly preserve a real `0`. **The defect is choosing
`0` as the fallback** — a value inside the measurement's own domain — instead of a sentinel
outside it or a separate sample count.

### Shell-structural shapes — a fallback-operator grep catches none of these

Shell has a second, larger family where **no fallback operator appears at all**; the shape
itself manufactures an answer. Two deploy-tooling PRs spent nineteen commits between them
closing these one at a time, so name them:

- **`cmd | grep -c .`** prints a confident `0` after the *producer* failed — byte-identical to a
  genuine zero.
- **A pipeline reports only the LAST command's exit status**, so a broken producer and a
  legitimate no-match are indistinguishable; and **`grep` exits non-zero on a no-match**, so a
  naive `|| handle_error` conflates the two in the opposite direction.
- **A `while` loop as the final stage of a pipeline runs in a subshell**, so an `exit N` inside
  it terminates only the subshell and the script continues past the abort — on a path that
  **drops databases**, in the precedent.
- **A bounded read presented as complete** — one unpaginated page, a `head -n`, a `--limit`.
- **A local-only operation succeeding after a failed remote read** — *confidently wrong* rather
  than empty, which no empty-check catches.
- **Malformed and genuinely-empty payloads extracting to the same value** — `null`, `{}`, an
  error body and non-JSON all yield the same empty string as a real empty list.

**Absence that GROWS a destructive set.** When a read feeds a set difference before a delete /
drop / prune / revoke — `to_delete = all - live` — a short or failed `live` read silently
**promotes live resources into the delete list**. Guard that read explicitly and abort on
failure; a short read must never be allowed to expand the destructive set.

**Converge on ONE guard, not N ad-hoc checks.** Both of those PRs stopped cycling only when the
author replaced per-site checks with one shared `require_read` helper / one three-outcome
contract applied to every read. After the *first* finding of this class on a surface, introduce
the shared guard — each remaining unguarded read is a separate reviewer round.

## The required posture: refuse, do not substitute

Absence is an **outcome**, not a value. Three sanctioned refusals, in preference order:

1. **Return an explicit inconclusive** — a nullable return, a result object with an
   `isConclusive()` the caller must consult, an enum case. Preferred when the caller can
   reasonably do something else.
2. **Throw** — when there is no sane caller behaviour and continuing would move money or write a
   record. A state transition must not complete on an unresolved input.
3. **Raise a durable operator-visible artifact** — a work item, a failing invariant, a loud CI
   error annotation — when the process must continue but a human has to know. **A log line at
   `info` is not this**; severity has to match the consequence. Precedent: a stock split arriving
   with a null ratio was logged at info, marked processed, and left holdings unchanged — a
   phantom overnight loss on a board reporting "settled".

What none of them do is hand the caller a number. If a nullable return is awkward for the
caller, that is an argument for a result object, not for `?? 0`.

**Prefer ONE shared result type over per-domain nullables.** A `Measurement` that carries
`Measured` / `Refused` / `InsufficientHistory` in an explicit state FIELD (never inferred from
the value), a total `fold(measured, absent)` with no default arm, and one named escape hatch to a
bare number is a wall the type itself holds — `m + 0` is a compile error and `m ?? 0` returns
`m`. Two postures live in it: a **producer** that cannot state its figure has a wiring defect and
throws; a **reader** of an untrusted payload has an absence and refuses. A second vocabulary for
the same fact diverges silently.

```text
// banned
total = sum(prices)                       // 0 when prices is empty
drift = (total - target) / target ?? 0    // "in band"

// required
sample = measure(prices)                  // {kept: n, excluded: m, value: v} or Refused
if sample is Refused:
    return Inconclusive(reason = sample.reason, kept = 0, excluded = m)
return Measured(drift = (sample.value - target) / target, kept = n, excluded = m)
```

### Propagate the refusal across every LAYER

**A refusal the service produces and the controller ignores is not a refusal.** The cautionary
case: the same defect recurred three times inside one PR, each time one layer further out —
backend sites fixed, then the controller still reading the raw threshold flag, then the view
layer still rendering an "on target" badge for an unmeasurable account. When you introduce an
inconclusive outcome, sweep every consumer: model / query scope, service, controller /
view-data, the view layer, export and assistant-tool payloads, console commands and scheduled
jobs, health invariants, seeders / factories / fixtures. That sweep defines DONE.

**The outermost consumer is the one a human reads, so it matters most.** In that same case an
assistant tool rolled the result up as `count(where exceeds_threshold = true)` — a boolean whose
`false` means both "measured, in band" and "could not be measured", so it told the operator in
prose that an unmeasurable account was within tolerance. **An inconclusive outcome folded into a
boolean, a count, a sum, or a rendered label is unrecoverable at exactly the layer nobody looks
past.**

### The exception-path form

**A swallowed failure that returns a default is this rule wearing a `catch` block.** A `catch`
returning `0`, an empty result, "no adjustment", or `clean()` hands the caller a fabricated value
instead of refusing. Apply the posture unchanged — and when a new refusal is introduced, trace
the throw through **every enclosing catch** and read each one's TYPE: a broad `catch (Exception)`
three frames up turns your refusal back into the default it was meant to replace.

## A genuine zero is a healthy sample — keep it distinguishable

`0` is a perfectly good measurement and often the *best* one: zero errors, zero drift, zero
unreconciled items. The failure is not that `0` appears; it is that a substituted `0` and a
measured `0` become indistinguishable downstream. **You cannot recover "did we measure?" from the
measurement**, so count samples separately from the aggregate:

- track `usable` / `failed` / `total` beside the measured value;
- **zero usable implies inconclusive**, plus a loud warning naming `total` / `usable` / `failed`
  **and whether the input set was empty** — an empty input set (`total = 0`, "the selector
  matched nothing") and a total producer failure (`total = failed`, "the producer is down") have
  opposite remediations, and a warning naming only the failure count cannot route to either;
- **partial implies a valid verdict flagged DEGRADED** (see the action contract below);
- log per-failure diagnostics (return code, status, a body snippet) **at the point of failure** —
  an inconclusive verdict with no diagnostics gives an operator nothing to act on.

**Assert the distinction in a test — two tests, not one.** An empty/failed source yields
inconclusive; a genuinely-zero source yields a conclusive zero. The measured-zero-versus-no-sample
case is the one reviewers never write, which is exactly why it ships.

**A read-only audit command is the same pair at the process boundary.** "Examined N rows, flagged
0" and "examined 0 rows" must never share an exit code or a printed line. Derive `CONCLUDED` /
`INCONCLUSIVE` from what was examined, through one seam every audit command ends in, so there is
no place to print "all clear" over an empty table — one audit command did exactly that for a
year.

## The Three-Outcome Audit — for anything that produces a verdict

**Mandatory when the change concludes something about the system** — a monitor, a gate, an
invariant, a health check, a soak, a dedup lookup. Run it in design (Phase 2), before the RED
test is written.

Any such check needs **THREE outcomes, not two: `pass` / `fail` / `inconclusive`.** Absence of
data is never evidence for either verdict. Collapsing it into `pass` silently **disarms the
safety mechanism** (the never-armed rollback above); collapsing it into `fail` **manufactures
false alarms operators learn to ignore** — a precedent in the other direction was a dedup check
that treated a failed lookup as "duplicate found" and blocked legitimate work until someone
noticed the queue had stopped.

Two design rules follow:

1. **Count samples separately from the aggregate** (the section above), so the check can tell
   `inconclusive` from `pass` and `DEGRADED` from full coverage.
2. **DEGRADED carries an ACTION CONTRACT, and it MUST be stated.** A degraded verdict is
   informative, not authoritative: it MAY drive an alert, a dashboard state, or a hold; it MUST
   NOT by itself trigger an automated high-impact action — a rollback, a deploy gate, a payment
   or fee action, any irreversible operation. If a surface genuinely needs `DEGRADED` to
   be actionable, state a **minimum coverage threshold** and **which specific actions** are
   permitted at it. Unstated means not permitted.

```text
verdict(samples):
    if samples.total == 0:            return Inconclusive(reason = "input set empty")
    if samples.usable == 0:           return Inconclusive(reason = "all reads failed", failed = samples.failed)
    v = evaluate(samples.usable_values)
    if samples.usable < samples.total: return Degraded(v, coverage = usable/total)   // alert, hold — never act
    return v                                                                          // Pass or Fail
```

## Detection recipe

Auditing an existing surface, cheapest first:

1. **Grep the banned shapes** (`?? 0`, `?: 0`, `sum(`, `avg(`, `first()`, `catch (`,
   `default =>`; in shell `:-0` / `// 0`, plus every `$(...)` capture and pipeline read against
   the structural shapes). Every hit is a candidate, not yet a finding.
2. **State the FAIL DIRECTION for each candidate.** SAFE (blocked / held / flagged / inconclusive
   / thrown) or UNSAFE (clean / zero / in-band / approved / processed / no-adjustment)? Only the
   UNSAFE ones are findings; UNSAFE on a money or compliance path rates at least High.
3. **Trace to what the user sees.** The finding is not "there is a `?? 0`"; it is "an unpriced
   holding renders as `0` on the value card and suppresses the proposal". A candidate you cannot
   trace to a wrong output is an observation.
4. **Audit the inverse** — a "legitimate skip" branch whose precondition is broader than
   intended, silently swallowing a whole class of records. Read the condition, not the comment.
5. **Check the guard.** Does an existing test assert the substituted value as expected? Then it
   blocks the fix and rewriting it is part of the fix
   ([tests-assert-behavior.md](tests-assert-behavior.md)).

## Where the rule applies

Every layer that consumes a read — application code, workflow and deploy shell, quality-gate
scripts, **and shell embedded in a Markdown file.** An agent definition, a skill body, or a
runbook containing probes and sweeps is **production code wearing a doc's clothing**: it ships
under a `docs:` prefix and is read as prose, so no code discipline fires at authoring time —
while the shell itself prunes worktrees or decides a PR is merge-ready. Review it as you would a
CI `run:` block; if it deletes, drops, prunes, force-pushes, or merges, every read guarding it
fails CLOSED.

## Related

- [remove-the-mechanism.md](remove-the-mechanism.md) — the refusal is the *posture*; that rule is
  the *shape*: a return type that cannot carry a fabricated number is the structural form.
- [adjacency-check.md](adjacency-check.md) — "absence renders as healthy" is the inventory row the
  inward question most often finds, and a fix FOR this rule can produce a harm OF this rule (a new
  alarm with no clearing path).
- [tests-assert-behavior.md](tests-assert-behavior.md) — the test that asserts the substituted
  value as expected, and why rewriting it is part of the fix.
