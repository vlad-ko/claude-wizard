# The complexity gate — how many agents, decided on structural signals

> Loaded on demand by the wizard SKILL. The always-on summary lives in the SKILL body
> ("Agent-Ensemble Dispatch"); this file holds the four structural signals, the three bands with
> their precedence, the two pass triggers, and the triage manifest that drives hybrid routing.

The gate is the **first** decision the orchestrator makes on any briefed unit of work: *how many
agents to spawn at all.* It is routing applied at the top level — classify the work, then
dispatch the cheapest shape that fits.

## Why a gate exists

The ensemble (persona lenses + `architect` + builders + `qa-engineer` + `doc-librarian`) is a
real cost, not a free upgrade. Every spawned agent burns its own context window, adds an
orchestrator-mediated hand-off (agents never talk peer-to-peer — the orchestrator reads each
result and bakes it into the next brief), and multiplies the seams where a misread brief compounds
into a wrong design that a builder faithfully implements. On a one-line fix, a seven-spawn
ensemble produces the *same* diff a single subagent would — after five hand-offs, at roughly
6–7x the context cost.

**So the default is "smaller."** The gate's job is to *justify* paying the multi-agent tax, not
to assume it. An under-powered single subagent that returns a scope-creep note is cheap to
escalate; an over-powered ensemble on a trivial fix has spent the tokens before anyone notices.

## The signals — structural, never keywords

Keyword lists rot: "refactor" covers a rename and a subsystem rewrite; "fix" covers a typo and
a race across six services. Classify on the shape of the work. The first four decide the band.

| Signal | What it measures | How to read it |
|---|---|---|
| **AC count** | Acceptance-criteria checkboxes on the issue | The same 3+ signal that triggers wizard mode, reused for the *intra-wizard* fan-out decision. Wizard-mode-on does NOT imply ensemble-on. |
| **Builder-distinct domain count** | Competence domains that each need their own builder *with a contract between them*: server logic, interactive view logic, the test layer, infra/CI | One → one builder. Two or more → specialists earn their keep. A migration plus a **read-only** display field is ONE domain; a service plus an **interactive** form that posts to it is two. |
| **Shared-state mutation** | Does the work modify data that more than one method or actor can mutate concurrently? | Needs the architect's invariant and concurrency map *before* code — exactly the perspective a lone builder skips under time pressure. |
| **Lifecycle transition** | Does it move a state machine or a lifecycle-owned field — a record's status, an async job's state, an approval? | Where a single-perspective build silently violates a guard; multi-lens hardening catches the missed state. |

The vocabulary is fixed: **"shared-state" means a mutation, "lifecycle" means a transition.** A
pure read, or a touch that changes no state, triggers nothing.

Two further signals are **pass triggers** — they fire a specific extra step and **never promote
work to Band 3 on their own**:

| Pass trigger | What it measures | What it fires |
|---|---|---|
| **Multi-concern footprint** | More than one *separable* concern — two things that could each merge alone and leave the codebase working. Distinct from domain count (two concerns can share a domain) and from AC count (one AC can hide two concerns). | ALWAYS triggers decomposition ([`phased-decomposition.md`](phased-decomposition.md)), at every band. A Band-2 *nudge* when the other four signals read Band 1. |
| **Shared-surface touch** | A surface more than one *actor* renders or reaches — a shared authenticated layout, a shared model predicate, shared CSS, a route another role can reach. Distinct from shared-*state*: this is render and visibility scoping across actors. | A **cross-actor leak-scoping lens pass** BEFORE the issue is treated as single-actor. Moves no band. |

## The three bands

**Precedence:** evaluate Band 3 first, then Band 2, then Band 1. A signal claimed by Band 3 is
never re-counted for a lower band; once precedence is applied the bands do not overlap.

### Band 3 — full ensemble

**Triggers — any ONE suffices:** 3+ AC, OR 2+ builder-distinct domains, OR a shared-state
mutation, OR a lifecycle transition.

**Route:** the sequence in [`ensemble-dispatch.md`](ensemble-dispatch.md) — persona lenses +
`doc-librarian` → `architect` → builders routed by file-domain, in parallel with `qa-engineer`
coverage authoring → independent verification. A **3+-AC single-domain** issue still clears
Band 3 — lenses, architect and qa-engineer earn their keep on a genuinely multi-criteria change —
but the *builders* are domain-routed, so it spawns the one relevant builder, not both.

*Example:* a per-record "pause" toggle — a new lifecycle field, a policy that blocks a background
dispatcher while paused, an interactive form, and audit logging. Five AC, two builder-distinct
domains, shared state (the dispatcher reads the field concurrently with the toggle), and a
lifecycle transition. Separated perspectives demonstrably reduce the missed-state risk; the tax
is justified.

### Band 1 — ONE general-purpose subagent

**Triggers — ALL of:** fewer than 3 AC, AND a single domain, AND no shared-state mutation, AND no
lifecycle transition.

**Route:** one subagent. No lenses, no architect, no roster, no qa-engineer. A pass trigger
modifies *what runs* without moving the band: a shared-surface touch runs the leak pass first; a
multi-concern footprint ships as separate sequential PRs off a filed plan, built by the same single
subagent.

*Example:* pin a factory field to a literal and fix the one assertion that reads it. One AC, one
domain. A three-lens hardening pass plus an architect plus a qa-engineer would produce the
identical two-line diff after five hand-offs — pure waste.

### Band 2 — orchestrator judgment, default SMALLER

**Triggers:** some signal, but not clearly enough — exactly 2 AC; a single domain with an
adjacent-domain smell; a "might touch shared state" the brief cannot confirm; a multi-concern
footprint whose other four signals all read Band 1. Anything the other two trigger sets do not
cleanly claim lands here.

**Route:** typically one subagent, or at most `architect` + one builder. Escalate into the Band-3
sequence only when the first pass surfaces a genuine gap — a scope-creep note exposing a second
domain, or an architect mapping exposing an invariant nobody saw. Defaulting smaller costs one
cheap re-spawn; defaulting to the ensemble over-spends on every display tweak.

*Example:* add a "last reviewed" timestamp column and surface it read-only on a detail view. Two
AC, one builder-distinct domain (a read-only display is not interactive view logic), no mutation,
no transition — one subagent.

## The gate decides how many AGENTS; decomposition decides how many PRs

These are independent questions, and conflating them breaks the gate in both directions: it would
force a trivial two-concern task into a seven-spawn ensemble, or license one improvised
multi-concern dispatch because the work "gated to Band 1." A small two-concern task gates to
Band 1 **and** still ships as two PRs. What is forbidden at *every* band is one improvised
multi-concern build. The test for "separable" is the decomposition spec's: *can each concern
merge on its own and leave the codebase working?* If not, it is one concern.

## Shared-surface touch → the cross-actor leak-scoping pass

Most issues are single-actor and route to a single subagent. But the reason to escalate to lenses
is not only AC count — it is **downstream effect on OTHER actors' areas**. When the change touches
a surface more than one actor reaches, run at least a leak-scoping lens pass even when every band
signal reads Band 1.

- **Which lenses:** those of the **other** actors who share the surface — not the primary actor's
  own. If you cannot cheaply tell who shares it, run them all; a read-only pass is cheap relative
  to a leak shipping.
- **Order and band:** a targeted pre-build check, not a promotion. The build still routes by band;
  the pass runs *first* so any finding folds into the build brief, and it pulls in no architect,
  roster or qa-engineer. If the pass itself surfaces a second domain or a shared-state mutation,
  *that* re-triggers the band evaluation — the surface signal alone does not.
- **What each lens asks** (both probes, in both of its phases): **feature parity** — "should an
  analogue of this capability exist for my persona?" — and **cross-actor scoping / leak** — "will
  it stay scoped, or surface on my persona's shared layout, predicate, style or reachable route?"
  "Not applicable" is a *conclusion* reached after both probes ran empty, never a skip.

Real precedent: an admin-only UI bug read Band 1 on every signal, and the one valuable cross-actor
finding was the leak check — would the admin's guided tour, mounted in the shared authenticated
layout, fire on another persona's dashboard? A pure AC-count gate would have skipped it.

## Hybrid routing — the triage manifest

The band decides *how many*; this decides *who*, within a band. Both poles fail on their own:
**one generalist under-verifies** (its systematic miss is the cross-cutting concern it never thinks
to look for), and **every heavyweight specialist self-selecting over-pays** (asked "do you apply
here?", a specialist answers yes far too often). The hybrid sits between: **objective signals
route builders DETERMINISTICALLY; the one judgment-heavy signal SELF-SELECTS among cheap read-only
lenses.** This shape was A/B-validated against both poles on a real batch.

### The manifest

Before any builder or lens is briefed, a **cheap general-purpose triage agent** reads the unit of
work and emits the objective footprint plus routing hints:

```text
files:            paths the change touches
layers:           backend | view | css | docs | infra (which are in the diff)
domains:          builder-distinct domains touched
actors:           the user personas whose surfaces the change reaches
ac_count:         number of acceptance criteria
doc_touch:        true if README / docs/** is in the footprint
frontend_logic:   true if client-side logic (a component factory, a formatter, a
                  coercion) is added or changed
new_module:       true if a new client-side or service module is introduced
data_shapes:      the contracts / DTOs / view-data keys the change moves
goal:             one-line statement of intent
band_estimate:    the band this footprint implies
builder:          the deterministic builder pick
lens_candidates:  the lenses the manifest SUGGESTS (the lenses make the final call)
```

### Deterministic builders, self-selecting lenses

- **Builders route off `files` / `layers` — no opt-out question.** A server-only diff goes to
  `backend-expert`, a view diff to `frontend-expert`, a two-domain diff spawns both. The footprint
  already answers the question; asking a heavyweight to opt out wastes its spawn.
- **Read-only lenses self-select.** `doc-librarian`, `qa-engineer` and the persona lenses each
  read the manifest and *decide* whether they apply. This is the one signal central routing keeps
  failing on (does an admin-only bug leak onto a shared layout? does this need a doc plan?), and a
  wrong "yes" costs one read-only pass, not a build.
- **`doc_touch: true` is a HARD trigger — the `doc-librarian` MUST be engaged**, for the Phase-1
  doc plan and the post-build doc verification. Precedent: a batch of tasks, doc-touching ones
  included, all routed to a single generalist and the librarian never spawned.
- **Band-keyed:** Band 1 → a competent generalist, no manifest tax (a trivial single-domain change
  has no cross-cutting concern by definition). Band 2/3 → the hybrid. Bring in the `architect`
  only on a **genuine design fork** — a concurrency invariant, a lifecycle transition, a decision
  with more than one defensible answer — not as a reflex on every Band-2/3 change.
- **Runs per PHASE** once work is decomposed: each phase's manifest is small, so `doc_touch` and
  the cross-actor probes are judged against what that phase touches, not the whole epic.

## Decision summary

```text
                     ┌──────────────────────────────────────────────────────┐
  briefed unit of    │ Signals: AC count · builder-distinct domains ·       │
  work ─────────────►│ shared-state MUTATION · lifecycle TRANSITION         │
                     │ Pass triggers: multi-concern · shared-surface        │
                     └──────────────────────────────────────────────────────┘
                                          │  (evaluate Band 3 → 2 → 1)
        ┌─────────────────────────────────┼─────────────────────────────────┐
        ▼                                 ▼                                 ▼
  <3 AC AND 1 domain               2 AC, or 1 domain with           3+ AC, OR 2+ domains,
  AND no mutation                  an adjacent smell, or            OR a mutation,
  AND no transition                "maybe shared-state"             OR a transition
        │                                 │                                 │
     BAND 1                            BAND 2                            BAND 3
  ONE general-purpose            judgment — DEFAULT               full ensemble via the
  subagent; no lenses,           SMALLER; escalate on a           triage manifest:
  no architect, no QA            surfaced gap                     deterministic builders +
                                                                  self-selecting lenses

  shared-surface touch → leak-scoping lens pass first (any band, no promotion)
  multi-concern footprint → decompose and file phases (any band, Band-2 nudge)
```

The gate is evaluated **first**, before any fan-out. The orchestrator never reaches "spawn the
lenses" without having cleared it into Band 3, or escalated into it from Band 2.
