# A test asserts BEHAVIOR, not SUCCESS

> Loaded on demand by the wizard SKILL. The always-on summary lives in the SKILL body ("A test
> asserts BEHAVIOR, not SUCCESS"); this file holds the three sub-rules, the one-line mutation
> procedure, the never-delete-a-file rule, the rewrite-the-blocking-test corollary, test at the
> seam, and where shape rules go instead.

**The rule:** a weak test does not merely miss a defect — it **encodes the defect as the
contract**, reads as coverage, and will actively **BLOCK** the fix. Real precedent: one
adversarial sweep of a production system found, in at least six of the high/critical issues it
filed, a green, plausible-looking test standing guard over the bug. One asserted a 4x-overstated
dividend *as the expected value*, with the arithmetic written in a comment beside it. One
asserted that a transport error marks a transfer REJECTED — the double-spend-enabling behaviour —
as the contract. One asserted an account created in a state that violated three invariants as
intended.

This is why it is an ordered step with a procedure, not a mindset bullet.

## The three sub-rules — all three required

Each of the precedents above failed a different one.

### 1. Assert the STATE CHANGE, not the call

"It returned without throwing", "a row exists", "the status was written" is not a test. Assert
the specific values, the counts, and **every** field a correct implementation must change — and
the ones it must NOT. Precedent: a verification test asserted the `verified` status write and
nothing about the downstream step advancing or the account activating, which was the actual
defect. A withdrawal test asserted the transfer row was created and never that the cash balance
changed; the missing debit WAS the bug.

```text
// weak
result = service.withdraw(account, 250)
assert result.ok

// asserts behaviour
before = account.cash_balance                     // pinned: 1000
result = service.withdraw(account, 250)
assert account.reload().cash_balance == 750       // the state change
assert transfer_rows(account).count == 1
assert transfer_rows(account).first.amount == 250
assert account.reload().status == ACTIVE          // the field it must NOT change
```

Test boundaries: if the code checks `> 0`, test with `0`, `1`, and `-1`. Assert side effects: if a
method updates three fields, assert all three.

### 2. A fixture must not make the defect UNDETECTABLE

When two quantities *could* diverge, the fixture must make them **deliberately unequal**. Pinning
them equal means either source passes and the test **cannot fail**. Precedent: a test asserted a
credit of `6000.00` from a fixture that set both the contribution amount and the transfer amount
to `1000.00` — reading either source produced a pass, so the test had no opinion about which one
the code read. This is the subtle one, it defeated an entire suite, and it is invisible in review
unless you ask: *"which distinct values would this fixture need for the assertion to
discriminate?"*

```text
// undetectable: both sources 1000 — either read passes
fixture(contribution_amount = 1000, transfer_amount = 1000)
assert credited == 6000

// discriminating: the two sources differ
fixture(contribution_amount = 1000, transfer_amount = 1300)
assert credited == 6 * 1000      // only the correct source produces this
```

Pin every fixture field the code under test BRANCHES on — not only the asserted-on ones. A
default the production path filters, orders or classifies on decides the outcome, so leaving it
to a random generator makes the result a dice roll. Precedent: a randomly generated purchase date
landed past a split's effective date and broke the main branch. Pin the clock too — a pinned
clock is not a substitute for pinned fixture fields, because the fixture generator ignores it.

### 3. Verify the teeth by MUTATION — actually run it

The ordered step, in this exact form:

1. **(i)** change **ONE LINE** of the implementation — an operator, a constant, a condition, a
   return value — noting the original value;
2. **(ii)** run the one test and confirm it goes RED;
3. **(iii)** **edit that line back** to what it was;
4. **(iv)** re-run and confirm GREEN, and `git diff` to confirm you actually put it back
   (verify by content hash, not by byte count — a same-length wrong value passes a size check).

If it stays green under the mutation it is not a test. **There is no backup step, because nothing
is destroyed** — you are reversing your own one-line edit, so there is no baseline to stage,
commit, or shelve, and no restore command to run.

This is a procedure, not a thought experiment. The sweep used it repeatedly and it repeatedly
earned its keep: a three-step mutation on one fix revealed progressively worse harm at each step,
and a 2x2 mutation matrix proved two rails were each independently load-bearing rather than one
being redundant.

Direction matters: to test an `assertContains`-style expectation, mutate by **adding** to the
result, not removing — a removal makes the assertion vacuously stronger. And a test whose expected
value equals the code's FALLBACK passes on a dead stub; pick an expected value the fallback cannot
produce.

#### NEVER delete, move, rename, or overwrite a file to force RED

**This bans a technique, not the existence of `rm`.** Never remove, move away, `rsync` over, or
rename a file to force a test outcome, produce a RED, or "reset" something you intend to put
back. **The tell is INTENT: if your plan involves that file existing again afterwards, do not
remove it.**

There is no test worth writing that requires REMOVING a file to force its outcome, and **a
deleted file is the WEAKER mutation**: "nothing works without this file" is trivially true and
pins nothing, while one changed condition pins the specific behaviour. The mutation you RUN is
ONE LINE — step (i) is the procedure and it does not widen. "If a mutation appears to need more
than editing a line or two, the mutation is wrong" is the **smell threshold** for recognising a
wrong mutation, never a licence to change two lines: when a mutation starts to sprawl, go find the
single line the test actually depends on, or report that the test pins no specific behaviour.

Real precedent: four incidents in one day of agents deleting a file to force RED and then needing
to restore it from git — one of which silently restored a file that had actually been corrupted
by the container's file mount, destroying the evidence and sending the next agent into the same
trap blind. Never use `git stash` as the shelf either — the stash ref is repo-global across
worktrees, so a stash in one worktree is visible to and poppable from every other.

**Needing to restore a file from git is an INCIDENT — stop and surface it to the user.** The
loop above is complete without a recovery mechanism, so reaching for one means something went
wrong outside it: the file was corrupted, another process altered it, or edits landed that
cannot be tracked back. Report the file, the state you found it in, and what you were doing —
**never quietly restore and carry on.** If a restore IS agreed, name the source explicitly
(`git restore --source=HEAD -- <file>`); a path-only restore reads from the index, not HEAD.

Three other acts get called "deleting a file" and were never in this rule's scope: reviewed
removal of genuinely dead code, documentation curation, and production code deleting a
regenerable user file at runtime.

## Corollary — a blocking test is rewritten as PART of the fix, and NAMED

A test that encodes the defect will go red on a correct change. **Do not weaken the change to keep
it green and do not delete the test silently**: rewrite it to the correct contract in the same
PR, and **name it in the PR description** — "`<SuiteName>` asserted the 4x-overstated dividend as
expected; rewritten to the correct per-share basis." Unnamed, a reviewer reads the test edit as
scope creep, or as coverage weakened to make CI green — and asks you to revert the one change
that mattered.

**Applies to test EDITS, not just new tests.** Before changing any assertion, ask which of the
three sub-rules the old one was violating; if the answer is "none, it was correct", you are about
to weaken a test.

**Select the tests to run by grepping the FACT, not by a class-name filter.** The tests that
encode the old contract are rarely in the class named after the feature you changed; they are
wherever the old value was asserted. Grep the constant, the label, the field name.

## Test at the seam — place each test by what it protects

Given a misplaced render assertion (an `assertSee` / string-contains on markup in a
controller-level test), "rewrite to a view-data assertion" and "just delete it" are BOTH usually
wrong. **Your server-side test runner tests LOGIC, not UI.** Relocate by what the assertion
PROTECTS:

| The assertion protects... | Route |
|---|---|
| **logic at a service / policy / model seam** (a query scope, a computed reason, an effective value) | unit-test it AT the seam, then **delete the render assertion as redundant** (expect net deletions) |
| **the controller's OWN data-shaping** (it filters / groups / maps what it hands the view) | re-express as a view-DATA contract assertion — the EXCEPTION, not the default |
| **pure presentation** (a CSS class, an ARIA attribute, literal markup) | flag it for the browser layer; do NOT delete-and-lose it |

**Over-deletion guard.** A unit test proves the logic is correct but not that the controller
WIRES it up — a delete relying on a new seam unit test still needs a thin controller-integration
smoke on the view-data contract. Never delete a DISTINCT-branch assertion (reviewed-vs-unreviewed,
fallback-non-empty) unless that branch's contract is separately asserted. Prove coverage lives
elsewhere BEFORE deleting; the review bots are the backstop, not the plan.

**Security caveat: any assertion load-bearing for tenant or isolation boundaries (tenant A cannot
see tenant B; a foreign id 404s) is re-expressed at its source — a policy/scope unit test or a
view-data exclusion — NEVER merely deleted.**

**Ask in order** when placing a new test: needs the database or server runtime (controller,
service, model, validation, migration, observer, job, policy, **view-DATA contract**) — the
server-side runner; pure client-side logic with no browser and no server — the JS unit runner;
needs a real browser, **or is any rendered-markup / CSS / accessibility / layout assertion** —
the browser layer. Never test client-side JS by shelling out to a JS runtime from the server-side
runner. New or changed pure client-side logic ships with its JS unit tests in the SAME PR.

## Shape rules go to a linter, never a source-scanning test

**A test must exercise runtime behaviour** — mount a controller, run a service, post a form,
query the schema. It must NOT scan the source tree for an anti-pattern (an unpinned clock, a
render assertion, a naming convention, a template foot-gun). Source-scanning "architectural
shape" guards belong in:

1. **a custom static-analysis rule** — gated at PR time, diff-aware, surfaced in the author's
   editor;
2. **a pre-commit hook** — for patterns the analyzer cannot see (template-only foot-guns);
3. **the human-readable rule** in your path-scoped rules file — the rationale and the opt-out.

Why: implementing shape rules as tests forces every PR through allowlist maintenance and
escape-aware regex, and under scope-narrowed CI the test-file-touching explodes wall-clock time.
Real precedent: a whole directory of source-scanning guard tests was deleted for CI cost; the
behavioural tests beside them (the ones that ran the real path) stayed. Before writing a guard
test, ask: *does this assert behaviour, or grep source?* If it greps source, write the analyzer
rule. And if you nonetheless write a source-text test, fixture the BYPASS axes — casing, Unicode
look-alikes, brace variants — or the reviewers will list them for you.

## Pin fixtures and the clock

- **Pin the clock** in setup and clear it in teardown; across a third-party date boundary pass the
  pinned now, never the literal `'now'`. A pinned clock can also **mask** a production timestamp
  bug — when the code under test computes from wall-clock, add one test at an unpinned edge.
- **Pin random-generator output** for any asserted-on field to an ASCII-safe literal.
- **Pin every field the code branches on** (sub-rule 2 above).
- **Money tests pin the period field** and use cents per unit; write the edge-case matrix
  (zero, negative, rounding boundary, period boundary) up front.
- **Tests never touch live external systems** — three rails: every external integration forced
  off with dummy credentials in the test config; stray outbound requests prevented in the base
  test case; a narrowest-seam fake in every test that legitimately exercises an external call.
  Never weaken the guard to make a test pass.

## Related

- [absence-is-not-a-value.md](absence-is-not-a-value.md) — the measured-zero-versus-no-sample
  case is the one reviewers never write; write both tests.
- [adjacency-check.md](adjacency-check.md) — "the fixture encodes the defect" is an inventory
  row; editing a test selects it.
- [phased-decomposition.md](phased-decomposition.md) — the builder-brief contract carries the three
  sub-rules, the mutation step, and the name-it-in-the-PR corollary, because a builder sees only
  its brief.
