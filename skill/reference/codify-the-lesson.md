# Codify the lesson while it is hot

> Loaded on demand by the wizard SKILL. The always-on summary lives in the SKILL body ("Codify
> the Lesson While It Is Hot"); this file holds the five triggers, the routing table for where a
> lesson goes, the two rules that make it stick, the bar, and the relationship to a nightly
> retrospective.

**Improving the skill is part of the flow, not a separate chore.** The SKILL, `CLAUDE.md`, the
`reference/` set and the agent definitions are only as good as the last lesson written into them
— a codification that stops accreting ages into exactly the stale guidance the process exists to
catch.

The whole v3 theme — rules that were guidance became ordered steps with a required artifact — is
this section applied to itself. Every ordered step in the skill exists because a preference lost
to momentum once and somebody wrote down what would have stopped it.

## The five triggers

"Improve continuously" with no named trigger never fires. Codify when one of these does:

1. **A rule existed but had no teeth, and was violated anyway.** Precedent: the small-PR rule said
   all four right things — one concern, independently mergeable, leaves the codebase working, flag
   what must not be batched — and a 20-file single unit of work happened regardless. The gap is
   closed by an ordered step (decompose BEFORE dispatch, with the phased plan FILED on the issue),
   not by restating the preference more firmly. **A preference loses to momentum; an ordered step
   that must produce an artifact does not.**
2. **Two rules pulled against each other, and the resolution was never written down.** Precedent:
   "fix ALL places with the same pattern" versus small-PR blast radius — resolved as **destination
   versus route** ("find broadly, fix completely, ship incrementally") only after the unresolved
   tension had already produced the 20-file worktree.
3. **A defect class recurred after being fixed once** — the fix was site-specific where the lesson
   was general. That is the systemic-fix rule one level up, applied to the process instead of the
   code.
4. **A reviewer caught something the process should have caught.** That is a **process** defect,
   not just a code defect; fixing only the code leaves the gap open for the next PR. Precedent:
   every failure in the incident record behind the adjacency check was caught by a reviewer and
   every success by the builder — the inventory existed, was filed, was named, and was not
   consulted. Nothing was missing except an ordered step that produces an artifact.
5. **A subagent had to be corrected mid-flight** on something a better brief would have prevented.
   The correction belongs in the brief contract, not only in that one thread — a builder sees
   only its brief plus the always-on rules, never this skill.

## Where the lesson goes

Reuse this split; do not invent a parallel taxonomy.

| Lesson shape | Home |
|---|---|
| An always-on rule every session must carry | `CLAUDE.md` — kept **dense**: a summary plus a pointer, never the full method ([context-economics.md](context-economics.md)) |
| A method or procedure | the matching `reference/*.md` |
| An ordered step in the flow | `SKILL.md` itself |
| A briefing instruction for builders | the builder-brief contract in [phased-decomposition.md](phased-decomposition.md) — the only text a builder reads |
| A lens or audit question | the lens template ([domain-user-lens.template.md](domain-user-lens.template.md)) or your architecture-review prompt |
| A boundary or grant on a dispatched agent | that agent's definition under `.claude/agents/` — its `description:` is what the orchestrator reads to pick it |

The routing is not cosmetic. A method text placed in `CLAUDE.md` is re-read on every API call of
every session; a brief instruction placed in a reference file is never seen by the builder it was
meant for. **Where a lesson lives decides whether it has teeth.**

## Two rules make it stick

1. **Attach the failure to the rule.** A rule stated abstractly gets read past; a rule carrying
   "here is what went wrong and what it cost" gets remembered — which is why every rule in this
   skill names its precedent in prose. Keep that as the required form: **no new rule without its
   incident.** The precedent need not be a number or a date; it needs the mechanism and the cost
   ("a 20-file single-unit fix happened despite the rule saying otherwise").
2. **Codify in the SAME session the lesson is learned**, while the specifics are still in hand.
   Deferred to a retrospective, a lesson loses the file paths, the reviewer comment, and the reason
   — which is most of its value. The edit is small and the context is free right now; neither
   stays true tomorrow.

Two authoring constraints travel with rule 1. **A `CLAUDE.md` edit is a summary+pointer edit** —
state what the rule is, why (one-line precedent), and where the method lives; re-inlining method
text into an always-resident file is the regression its budget exists to prevent. And **an
escalated rule binds only in a checkout that has it** — when a lesson is promoted from local
memory into a tracked file, keep the memory entry until the tracked edit has merged, or a stale
checkout silently loses the rule.

## The bar

**Not every lesson deserves codification.** A one-off mistake is not a pattern, and a skill that
accretes every incident becomes unreadable — its own failure mode, because **an unread rule has no
teeth either**, exactly like the toothless rule in trigger 1.

A lesson earns a place if BOTH hold:

- it would have **changed the outcome** — had the rule existed in this form, the incident would
  not have happened; and
- it is likely to **recur** — the shape is general, not an accident of this one task.

Below that bar it goes to **memory**, not to the skill: a per-project memory file the orchestrator
reads at session start, indexed one line per entry, held to its own byte budget. Memory is where a
lesson waits to prove recurrence; the skill is where it goes once it has.

**Honest rung:** this is guidance with a named trigger set, not a mechanism. The enforcement
points are the Phase 7 self-review line ("lessons codified: which edit, or an explicit *none
cleared the bar*") and the summary output at the end of a run, which reports the same either way.
An empty "lessons codified" line on a run that hit a trigger is the tell.

## Relationship to a nightly retrospective — optional, complementary

A **nightly retrospective skill** — one that mines recent merged PRs and commits for patterns,
writes lessons to memory by default, and escalates to a `chore:` PR against the skill or
`CLAUDE.md` only when a stricter bar holds (broad applicability, proven across three or more
distinct sessions, read-on-load necessity) — is a useful counterpart, not a replacement.

This section is the **in-session** loop for a lesson learned right now, mid-flight. The nightly
pass catches what the in-session pass missed and is what confirms recurrence across sessions; the
in-session pass captures what the nightly pass can no longer reconstruct after the fact. When
unsure whether a lesson clears the bar for a skill edit rather than a memory entry, the nightly
skill's stricter criteria are the canonical tie-break. If you do not run one, the in-session loop
plus memory is sufficient; the recurrence check then falls to the orchestrator reading memory at
session start.

## Related

- [context-economics.md](context-economics.md) — the summary+pointer budget that constrains the
  `CLAUDE.md` row of the routing table.
- [phased-decomposition.md](phased-decomposition.md) — the builder-brief contract, the home for
  trigger 5.
- [adjacency-check.md](adjacency-check.md) — the worked case of trigger 4 becoming an ordered step
  with a required artifact.
