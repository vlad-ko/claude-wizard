# Common Patterns & Anti-Patterns

Quick reference for the wizard skill. These are the genuinely portable patterns — they hold in
any language or framework.

## Concurrency Patterns

### TOCTOU Prevention (Time-of-Check to Time-of-Use)

```
// WRONG: Race condition between check and update
status = read(record)           // Time of Check
// ... another process modifies record here ...
if status == "pending":         // Time of Use (STALE!)
    update(record, "processing")

// CORRECT: Atomic check-and-act with locking
lock(record)
status = read(record)           // Read under lock
if status == "pending":
    update(record, "processing")
unlock(record)
```

This applies to any shared mutable state: databases, files, caches, APIs.

### Atomic State Transitions

```
// CORRECT: Single atomic operation
affected = UPDATE records
    SET status = 'processing', started_at = now()
    WHERE id = ? AND status = 'pending'

if affected > 0:
    // Success - proceed
else:
    // State already changed - handle appropriately
```

### Error Handling in Transactions

```
// BUG: Audit record is rolled back with the transaction
begin_transaction()
    create_audit_event("operation_failed")  // rolled back!
    update(record, status: "blocked")       // rolled back!
    raise Error("something went wrong")      // triggers rollback
end_transaction()

// CORRECT: Error state persists outside the transaction
try:
    begin_transaction()
        do_work()
    end_transaction()
catch Error as e:
    create_audit_event("operation_failed")  // persists
    update(record, status: "blocked")       // persists
    raise e
```

## Absence Patterns

### Refuse, do not substitute

```
// WRONG: absence renders as a healthy value the reader will trust
total = sum(rows) ?? 0            // no rows and "zero total" now look identical
rate  = first(samples) ?? 0.0     // no sample becomes a measured 0.0
count = ${count:-0}               // shell: an unreadable count becomes 0

// RIGHT: absence is a distinct outcome — a sentinel, a throw, or a separate sample count
if rows.is_empty(): return Inconclusive("no rows for period")
result = { value: sum(rows), samples: rows.length }   // samples == 0 speaks for itself
```

The defect is never the operator — it is choosing `0` (a value inside the domain) instead of
something outside it. A genuine `0` is a healthy sample and must stay distinguishable from
no-sample.

### Three outcomes for any verdict

```
// WRONG: two outcomes; missing data silently becomes one of them
healthy = all(checks.map(c => c.ok))     // an empty `checks` is "healthy"

// RIGHT: pass / fail / INCONCLUSIVE, with the sample counts alongside
if checks.is_empty():        verdict = INCONCLUSIVE, warn("0 of 0 usable")
elif any_failed(checks):     verdict = FAIL
elif usable < total:         verdict = PASS (DEGRADED: usable/total)   // may alert, never auto-act
else:                        verdict = PASS
```

### A swallowed failure is the exception-path form

```
// WRONG: the caller receives a fabricated value
try:    return compute_adjustment(x)
catch:  return 0                      // "no adjustment" is a claim, not a refusal

// RIGHT: refuse, and leave a durable operator-visible artifact — an info log is not one
catch e: log_error(context, e); raise Inconclusive(e)
```

## Mechanism Patterns

### Remove the mechanism, do not add a guard

```
// GUARD (rung 4): the wrong action is still expressible; a new caller next year can take it
if !record.is_settled: record.settle()

// SEAM (rung 2): every writer converges on one authoritative path that cannot be gone around
SettlementService.settle(record)   // the only place `settled_at` is ever written

// TYPE (rung 1): the wrong action is not expressible
UnsettledRecord.settle() -> SettledRecord   // a SettledRecord has no settle()
```

The operative test: *could a NEW caller written next year, by someone who has not read this issue,
still do the wrong thing?* If yes, it is a guard. Take the highest rung; if a guard is all there is,
say so in the PR and name the follow-up.

## Test Patterns

### The one-line mutation (verify the teeth)

```
// (i)  change ONE line of the implementation — an operator, a constant, a condition
-   if amount > limit:
+   if amount >= limit:
// (ii) run the one test — it MUST go RED
// (iii) edit the line back
// (iv) run again — GREEN; `git diff` shows nothing
//
// There is no backup step because nothing is destroyed. NEVER delete, move, rename, or
// overwrite a file to force RED — "nothing works without this file" pins nothing.
```

### A fixture must not make the defect undetectable

```
// WEAK: both sources hold the same value, so the test cannot tell which one the code read
transfer = create(amount: 1000, contribution: 1000)
assert credited == 1000          // passes whether the code read `amount` OR `contribution`

// STRONG: deliberately unequal, so only the correct source passes
transfer = create(amount: 1000, contribution: 250)
assert credited == 1000
```

### Mutation-Resistant Assertions

```
// WEAK: Just checks success
assert result == true

// STRONG: Checks specific values that would catch mutations
assert result.count == 5
assert result.status == "completed"
assert result.completed_at != null
assert result.items[0].name == "expected"
```

### Boundary Testing

```
// If code checks `value > 0`, test:
test_with_value(0)   // boundary
test_with_value(1)   // just above
test_with_value(-1)  // just below

// If code checks string length:
test_with_empty_string("")
test_with_single_char("a")
test_with_max_length("a" * MAX)
test_with_over_max("a" * (MAX + 1))
```

### Determinism: pin non-deterministic fixtures and the clock

```
// FLAKY: random fixture data can collide with an assertion or trip a rule on a later run
user = factory.create(name: fake.name())
assert page.contains(user.name)   // breaks the day fake() rolls a name with an escaped char

// STABLE: pin the field to a literal you control
user = factory.create(name: "Test User")

// FLAKY: a relative time window flakes when the suite runs at the wrong wall-clock moment
assert record.created_at > now().minus(30, minutes)

// STABLE: freeze the clock in setup, restore in teardown
freeze_clock("2026-01-01 12:00:00 UTC")
```

### Test the right thing in the right layer

```
// WRONG: asserting rendered markup from a server-side unit test
assert response.body.contains('class="btn-primary"')   // breaks on any cosmetic refactor

// RIGHT: assert the typed data CONTRACT the server hands the view
assert response.view_data["summary"]["status"] == Status.COMPLETED
```

Server logic → server test suite. Pure client-side logic → client test runner.
Rendered markup / CSS / accessibility → a browser-driven layer.

## Implementation Patterns

### Constants Over Magic Values

```
// WRONG: Hard-coded strings scattered across the codebase
status = "active"
type = "premium"

// CORRECT: Centralized constants
status = Status.ACTIVE
type = AccountType.PREMIUM
```

### Don't Repeat Yourself (DRY) — But Wisely

```
// When fixing a bug in one place, ask:
// "Where else does this same pattern exist?"
grep -rn "the_pattern" src/

// Fix ALL occurrences, or extract a shared function.
// One-off fixes that leave duplicates create tech debt.
```

## Orchestration Patterns (delegated mode)

### Commit is the handoff boundary

```
// Worker: design → ... → self-review → git commit (LOCAL) → return branch + SHA
// Orchestrator: verify diff → git push → open PR → review cycle → merge-ready
// The worker NEVER pushes. The orchestrator NEVER authors repo code (it dispatches a fix-subagent).
```

### Mediated hand-off (agents never talk peer-to-peer)

```
// WRONG: imagining agent A hands its output to agent B directly
lens.report --> architect.brief   // impossible: isolated contexts, one result each

// RIGHT: the orchestrator is the integrator
orchestrator reads lens.report --> distills --> writes into architect.brief
```

### Non-overlapping file ownership for concurrent agents

```
// Concurrent agents in one worktree race the git index. Partition by EXPLICIT file list:
backend-expert  owns app/** + its own RED test file   -> git add <those explicit paths>
frontend-expert owns the view files                   -> git add <those explicit paths>
qa-engineer     owns the OTHER test files              -> git add <those explicit paths>
// NEVER `git add -A` — it sweeps a sibling agent's in-flight edits into the wrong commit.
```

### The adjacency block (in every PR body)

```
### Adjacency check
- Outward: `eligibility` is now derived in EligibilityService only — the view and the
  export previously computed it themselves; both now read the service (3 sites → 1).
- Inward: relies on the tenant-scope rule firing for OwnedModel — opened the rule; its
  trigger excludes models without `owner_id`, and this model has one. Covered.
- Adjacent: the nightly reconcile still sums an empty set to 0 — filed, not fixed here.
```

Outward: every fact this diff states — where else is it stated, do they agree? Inward: every
fact this diff relies on — which guard proves it, and CAN that guard fire here? An adjacent
problem is filed, never fixed in place, never dropped.

### Wake on events, not on a clock

```
// WRONG: a recurring tick — every fire re-reads the whole resident context
schedule_wakeup(every: 180s)

// RIGHT: the events already exist — push, subagent return, user turn, a PR-state question.
// Arm ONE wakeup only against a named pending external state nothing will notify you about:
schedule_wakeup(after: ci_run_expected_duration, reason: "CI run on PR N")
```

### Root cause in a brief is a HYPOTHESIS

```
// WRONG: "confirmed: the 500 is a null-deref on user_id" baked into the brief as fact
//        -> the downstream agent burns its budget refuting a schema-impossible claim

// RIGHT: label it a hypothesis and run the cheapest disconfirming check BEFORE dispatch
//        "hypothesis: null-deref on user_id" + a 30-second schema/grep check first
```

## Verification Commands

```bash
# Check a function/method exists before using it
grep -r "function methodName" src/

# Find all usages of a pattern (for systemic fixes)
grep -rn "pattern" src/

# Check for existing constants before hard-coding
grep -rn "CONSTANT_NAME" src/

# Before pushing a worker's branch: verify the diff against FRESH origin
git fetch origin && git diff --stat origin/main HEAD

# Orphan conflict markers left after a resolve
grep -rnE '^(<<<<<<<|=======|>>>>>>>)' .

# Review what you're about to commit
git diff --staged

# Measure the test-running budget (fail closed to 1 if either read fails)
sysctl -n hw.ncpu || nproc          # host cores
docker info --format '{{.NCPU}}'    # container VM cores, if the suite runs inside one

# Clean slate at the end of a task
git status --short && git worktree list && git branch --merged main
```

## The Architect's Pre-Flight

Before writing ANY code, answer:

1. What are ALL the ways this code can be reached?
2. What other code modifies the same data?
3. What happens under concurrent access?
4. What are the edge cases? (null, zero, negative, max, empty, duplicate)
5. What invariants must this code maintain?
6. How would I test that those invariants hold?

If you can't answer these, you're not ready to write code yet.
